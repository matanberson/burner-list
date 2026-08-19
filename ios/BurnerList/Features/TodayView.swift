import SwiftUI

enum TaskScope: String, CaseIterable, Identifiable {
    case today, all, upcoming, previous

    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "Today's List"
        case .all: "All Tasks"
        case .upcoming: "Upcoming"
        case .previous: "Previous"
        }
    }
    var icon: String {
        switch self {
        case .all: "checklist"
        case .today: "calendar"
        case .upcoming: "calendar.badge.clock"
        case .previous: "clock.arrow.circlepath"
        }
    }

    var subtitle: String? {
        switch self {
        case .today: nil
        case .all: "Every open task, in one place."
        case .upcoming: "Plan and open future Burner Lists."
        case .previous: "Review your earlier Burner Lists."
        }
    }

    func includes(_ task: BurnerTaskRow, todayKey: String, selectedListKey: String?) -> Bool {
        switch self {
        case .today:
            task.scheduledDate == todayKey || (task.scheduledDate == nil && task.listKey == selectedListKey)
        case .all:
            true
        case .upcoming:
            (task.scheduledDate ?? "") > todayKey
        case .previous:
            !(task.scheduledDate ?? "").isEmpty && (task.scheduledDate ?? "") < todayKey
        }
    }
}

enum TaskLayout: String, CaseIterable, Identifiable {
    case burner, kanban, list

    var id: String { rawValue }
    var title: String {
        switch self {
        case .burner: "Burner List"
        case .kanban: "Kanban"
        case .list: "List"
        }
    }
    var icon: String {
        switch self {
        case .burner: "flame"
        case .kanban: "rectangle.split.3x1"
        case .list: "list.bullet"
        }
    }
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var list: BurnerListRow?
    @Published var availableLists: [BurnerListRow] = []
    @Published var selectedListKey: String?
    @Published var tasks: [BurnerTaskRow] = []
    @Published var scope: TaskScope = .today
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let session: UserSession
    private let repository: BurnerRepository
    let dateKey: String

    init(session: UserSession, repository: BurnerRepository, dateKey: String = Date.burnerKey()) {
        self.session = session
        self.repository = repository
        self.dateKey = dateKey
    }

    var visibleTasks: [BurnerTaskRow] {
        tasks.filter { scope.includes($0, todayKey: dateKey, selectedListKey: selectedListKey) }
        .sorted {
            if $0.scheduledDate != $1.scheduledDate { return ($0.scheduledDate ?? "") < ($1.scheduledDate ?? "") }
            if $0.zone != $1.zone { return $0.zone.rawValue < $1.zone.rawValue }
            return $0.sortOrder < $1.sortOrder
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            availableLists = try await repository.loadLists(session: session)
            selectedListKey = availableLists.first(where: { $0.dateKey == dateKey })?.key ?? selectedListKey
            if scope == .today {
                let snapshot = if let selectedListKey {
                    try await repository.loadList(session: session, key: selectedListKey)
                } else {
                    try await repository.loadToday(session: session, dateKey: dateKey)
                }
                list = snapshot.0
                tasks = snapshot.1
            } else {
                var rows: [String: BurnerTaskRow] = [:]
                for candidate in availableLists {
                    let snapshot = try await repository.loadList(session: session, key: candidate.key)
                    for task in snapshot.1 where task.deletedAt == nil { rows[task.id] = task }
                }
                tasks = Array(rows.values)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func add(text: String, zone: BurnerZone) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let order = (tasks.filter { $0.zone == zone }.map(\.sortOrder).max() ?? -1) + 1
        let targetListKey = list?.key ?? dateKey
        let task = BurnerTaskRow(
            userId: session.user.id, id: UUID().uuidString.lowercased(), listKey: targetListKey,
            zone: zone, text: trimmed, done: false, sortOrder: order, inProgress: false,
            boardOrder: order, scheduledDate: list?.dateKey ?? dateKey, completedAt: nil,
            updatedAt: Date(), deletedAt: nil
        )
        tasks.append(task)
        do {
            if list == nil { try await repository.ensureList(session: session, dateKey: dateKey) }
            try await repository.saveTask(task, session: session)
        } catch {
            tasks.removeAll { $0.id == task.id }
            errorMessage = error.localizedDescription
        }
    }

    func toggle(_ task: BurnerTaskRow) async {
        await mutate(task) { row in
            row.done.toggle()
            row.completedAt = row.done ? Date() : nil
            if row.done { row.inProgress = false }
        }
    }

    func setKanbanState(_ task: BurnerTaskRow, done: Bool, inProgress: Bool) async {
        await mutate(task) { row in
            row.done = done
            row.inProgress = inProgress
            row.completedAt = done ? Date() : nil
        }
    }

    func save(_ edited: BurnerTaskRow, previousListKey: String, scheduledDate: String?) async {
        var next = edited
        next.text = next.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.text.isEmpty else { return }
        next.scheduledDate = scheduledDate
        if let scheduledDate {
            let target = availableLists.first(where: { $0.dateKey == scheduledDate })
            next.listKey = target?.key ?? scheduledDate
            if target == nil { try? await repository.ensureList(session: session, dateKey: scheduledDate) }
        } else {
            next.listKey = "__inbox__"
            next.zone = .unscheduled
            if !availableLists.contains(where: { $0.key == "__inbox__" }) {
                try? await repository.ensureInbox(session: session, todayKey: dateKey)
            }
        }
        next.updatedAt = Date()
        do {
            try await repository.updateTask(next, previousListKey: previousListKey, session: session)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ task: BurnerTaskRow) async {
        let previous = tasks
        tasks.removeAll { $0.id == task.id }
        do {
            try await repository.deleteTask(task, session: session)
        } catch {
            tasks = previous
            errorMessage = error.localizedDescription
        }
    }

    private func mutate(_ task: BurnerTaskRow, change: (inout BurnerTaskRow) -> Void) async {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        let previous = tasks[index]
        change(&tasks[index])
        tasks[index].updatedAt = Date()
        do {
            try await repository.saveTask(tasks[index], session: session)
        } catch {
            tasks[index] = previous
            errorMessage = error.localizedDescription
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var app: AppSession
    @StateObject private var model: TodayViewModel
    @AppStorage("task-layout") private var layout = TaskLayout.burner
    @State private var addingZone: BurnerZone?
    @State private var newTask = ""
    @State private var editingTask: BurnerTaskRow?
    @FocusState private var taskFieldFocused: Bool

    init(session: UserSession, repository: BurnerRepository) {
        _model = StateObject(wrappedValue: TodayViewModel(session: session, repository: repository))
    }

    var body: some View {
        TabView(selection: $model.scope) {
            ForEach(TaskScope.allCases) { scope in
                NavigationStack {
                    scopeScreen(scope)
                }
                .tabItem {
                    BurnerScopeTabLabel(title: scope.title, systemImage: scope.icon)
                }
                .tag(scope)
            }
        }
        .tint(BurnerTheme.textMid)
        .overlay { if model.isLoading { ProgressView().padding(22).background(.regularMaterial, in: Circle()) } }
        .task { await model.load() }
        .onChange(of: model.scope) { _, _ in Task { await model.load() } }
        .sheet(item: $editingTask) { task in
            TaskDetailView(task: task, availableLists: model.availableLists) { edited, date in
                Task { await model.save(edited, previousListKey: task.listKey, scheduledDate: date) }
            } onDelete: {
                Task { await model.delete(task) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Couldn’t sync", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
    }

    private func scopeScreen(_ scope: TaskScope) -> some View {
        ZStack {
            BurnerTheme.paper.ignoresSafeArea()
            content(for: scope)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BurnerTheme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BurnerDateHeader(
                    title: scope.title,
                    subtitle: scope == .today ? formattedDate : scope.subtitle
                )
            }
            ToolbarItem(placement: .topBarTrailing) {
                viewMenu
            }
        }
    }

    private var viewMenu: some View {
        Menu {
            Picker("View", selection: $layout) {
                ForEach(TaskLayout.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon).tag(mode)
                }
            }
            Divider()
            Button("Sign out", role: .destructive) {
                Task { await app.signOut() }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(width: BurnerTokens.space8, height: BurnerTokens.space8)
        }
        .accessibilityLabel("More options")
    }

    @ViewBuilder private func content(for scope: TaskScope) -> some View {
        ScrollView {
            switch layout {
            case .burner where scope == .today:
                burnerContent
            case .kanban:
                kanbanContent
            default:
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable { await model.load() }
    }

    private var burnerContent: some View {
        VStack(spacing: 0) {
            zoneView(.front, projectName: model.list?.frontName, placeholder: "Your #1 priority")
            Divider().overlay(BurnerTheme.border)
            zoneView(.back, projectName: model.list?.backName, placeholder: "Your #2 project")
            Divider().overlay(BurnerTheme.border)
            zoneView(.sink, projectName: nil, placeholder: nil)
        }
        .background(BurnerTheme.paper)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(BurnerTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 8).padding(.bottom, 32)
    }

    private var listContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if model.visibleTasks.isEmpty { emptyState }
            ForEach(model.visibleTasks) { task in taskRow(task, showsDate: model.scope != .today) }
        }
        .padding(.horizontal, 20).padding(.bottom, 30)
    }

    private var kanbanContent: some View {
        VStack(spacing: 14) {
            kanbanColumn("Backlog", tasks: model.visibleTasks.filter { !$0.done && !$0.inProgress })
            kanbanColumn("Doing", tasks: model.visibleTasks.filter { !$0.done && $0.inProgress })
            kanbanColumn("Done", tasks: model.visibleTasks.filter(\.done))
        }
        .padding(.horizontal, 12).padding(.bottom, 30)
    }

    private func kanbanColumn(_ title: String, tasks: [BurnerTaskRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(BurnerTheme.body(11, weight: .semibold)).tracking(0.6).foregroundStyle(BurnerTheme.textMid)
            ForEach(tasks) { task in
                HStack(spacing: 6) {
                    taskRow(task, showsDate: true)
                    Menu {
                        Button("Move to Backlog") { Task { await model.setKanbanState(task, done: false, inProgress: false) } }
                        Button("Move to Doing") { Task { await model.setKanbanState(task, done: false, inProgress: true) } }
                        Button("Move to Done") { Task { await model.setKanbanState(task, done: true, inProgress: false) } }
                    } label: {
                        Image(systemName: "ellipsis").foregroundStyle(BurnerTheme.textSoft).frame(width: 30, height: 36)
                    }
                    .accessibilityLabel("Move task")
                }
            }
            if tasks.isEmpty { Text("No tasks").font(BurnerTheme.body(13)).foregroundStyle(BurnerTheme.textFaint).padding(.vertical, 12) }
        }
        .padding(BurnerTokens.space4).background(BurnerTheme.fieldSurface.opacity(0.45), in: RoundedRectangle(cornerRadius: BurnerTokens.radiusLG))
        .overlay(RoundedRectangle(cornerRadius: BurnerTokens.radiusLG).stroke(BurnerTheme.border))
    }

    private func zoneView(_ zone: BurnerZone, projectName: String?, placeholder: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(zone.title.uppercased()).font(BurnerTheme.body(11, weight: .semibold)).tracking(0.6).foregroundStyle(BurnerTheme.textMid).padding(.bottom, 7)
            if let placeholder {
                Text((projectName?.isEmpty == false ? projectName : placeholder) ?? placeholder)
                    .font(BurnerTheme.body(15, weight: projectName?.isEmpty == false ? .semibold : .regular))
                    .foregroundStyle(projectName?.isEmpty == false ? BurnerTheme.textDark : BurnerTheme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5)
                    .overlay(alignment: .bottom) { Rectangle().fill(BurnerTheme.borderStrong).frame(height: 1.5) }.padding(.bottom, 12)
            }
            ForEach(model.visibleTasks.filter { $0.zone == zone }) { task in taskRow(task) }
            if addingZone == zone {
                HStack(spacing: 8) {
                    Circle().stroke(BurnerTheme.textFaint, lineWidth: 1.4).frame(width: 17, height: 17)
                    TextField("Task", text: $newTask).focused($taskFieldFocused).submitLabel(.done).onSubmit { addTask(to: zone) }
                    Button("Add") { addTask(to: zone) }
                }.font(BurnerTheme.body(14)).padding(.vertical, 7)
            } else {
                Button { addingZone = zone; newTask = ""; taskFieldFocused = true } label: {
                    Label("Add task", systemImage: "plus.circle").font(BurnerTheme.body(13)).foregroundStyle(BurnerTheme.textFaint).padding(.vertical, 7)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 30).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func taskRow(_ task: BurnerTaskRow, showsDate: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button { Task { await model.toggle(task) } } label: { checkbox(for: task) }
                .buttonStyle(.plain).accessibilityLabel(task.done ? "Mark incomplete" : "Complete task")
            Button { editingTask = task } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.text).font(BurnerTheme.body(14)).foregroundStyle(task.done ? BurnerTheme.textFaint : BurnerTheme.textDark)
                        .strikethrough(task.done).frame(maxWidth: .infinity, alignment: .leading).multilineTextAlignment(.leading)
                    if showsDate, let date = task.scheduledDate {
                        Label(shortDate(date), systemImage: "calendar").font(BurnerTheme.body(11)).foregroundStyle(BurnerTheme.textSoft)
                    }
                }
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 10).contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(BurnerTheme.border).frame(height: 1) }
        .contextMenu {
            Button { editingTask = task } label: { Label("Edit", systemImage: "pencil") }
            Button { editingTask = task } label: { Label("Reschedule", systemImage: "calendar") }
            Button(role: .destructive) { Task { await model.delete(task) } } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func checkbox(for task: BurnerTaskRow) -> some View {
        ZStack {
            Circle().fill(task.done ? BurnerTheme.textMid : .clear)
                .overlay(Circle().stroke(task.done ? BurnerTheme.textMid : BurnerTheme.textFaint, lineWidth: 1.4))
            if task.done { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) }
        }.frame(width: 19, height: 19)
    }

    private var emptyState: some View {
        ContentUnavailableView("No tasks", systemImage: model.scope.icon, description: Text("Tasks in this view will appear here."))
            .frame(maxWidth: .infinity).padding(.top, 70)
    }

    private var formattedDate: String { shortDate(model.list?.dateKey ?? model.dateKey) }
    private func shortDate(_ key: String) -> String {
        guard let date = DateFormatter.burnerDate.date(from: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
    private func addTask(to zone: BurnerZone) { let text = newTask; newTask = ""; addingZone = nil; Task { await model.add(text: text, zone: zone) } }
}

private struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var task: BurnerTaskRow
    @State private var isScheduled: Bool
    @State private var scheduledDate: Date
    let availableLists: [BurnerListRow]
    let onSave: (BurnerTaskRow, String?) -> Void
    let onDelete: () -> Void

    init(task: BurnerTaskRow, availableLists: [BurnerListRow], onSave: @escaping (BurnerTaskRow, String?) -> Void, onDelete: @escaping () -> Void) {
        _task = State(initialValue: task)
        _isScheduled = State(initialValue: task.scheduledDate != nil)
        _scheduledDate = State(initialValue: task.scheduledDate.flatMap { DateFormatter.burnerDate.date(from: $0) } ?? Date())
        self.availableLists = availableLists
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task name", text: $task.text, axis: .vertical).lineLimit(2...6)
                    Toggle("Completed", isOn: $task.done)
                }
                Section("Schedule") {
                    Toggle("Scheduled", isOn: $isScheduled)
                    if isScheduled { DatePicker("Date", selection: $scheduledDate, displayedComponents: .date) }
                }
                Section("Burner") {
                    Picker("Section", selection: $task.zone) {
                        ForEach(BurnerZone.allCases) { Text($0.title).tag($0) }
                    }
                }
                Section { Button("Delete task", role: .destructive) { onDelete(); dismiss() } }
            }
            .navigationTitle("Task details").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.completedAt = task.done ? (task.completedAt ?? Date()) : nil
                        onSave(task, isScheduled ? Date.burnerKey(for: scheduledDate) : nil)
                        dismiss()
                    }.disabled(task.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

extension DateFormatter {
    static let burnerDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
