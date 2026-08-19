import Foundation

protocol BurnerRepository: Sendable {
    func loadLists(session: UserSession) async throws -> [BurnerListRow]
    func loadList(session: UserSession, key: String) async throws -> (BurnerListRow?, [BurnerTaskRow])
    func loadToday(session: UserSession, dateKey: String) async throws -> (BurnerListRow?, [BurnerTaskRow])
    func ensureList(session: UserSession, dateKey: String) async throws
    func ensureInbox(session: UserSession, todayKey: String) async throws
    func saveTask(_ task: BurnerTaskRow, session: UserSession) async throws
    func updateTask(_ task: BurnerTaskRow, previousListKey: String, session: UserSession) async throws
    func deleteTask(_ task: BurnerTaskRow, session: UserSession) async throws
}

actor SupabaseBurnerRepository: BurnerRepository {
    private let configuration: AppConfiguration
    private let client: URLSession

    init(configuration: AppConfiguration, client: URLSession = .shared) {
        self.configuration = configuration
        self.client = client
    }

    func loadToday(session: UserSession, dateKey: String) async throws -> (BurnerListRow?, [BurnerTaskRow]) {
        var v2Snapshot: (BurnerListRow, [BurnerTaskRow])?
        var v2Error: Error?
        do {
            v2Snapshot = try await loadV2Today(session: session, dateKey: dateKey)
        } catch {
            v2Error = error
        }
        let legacySnapshot = try await loadLegacyToday(session: session, dateKey: dateKey)
        switch (v2Snapshot, legacySnapshot) {
        case let (.some(v2), .some(legacy)):
            return legacy.0.updatedAt > v2.0.updatedAt ? legacy : v2
        case let (.some(v2), .none): return v2
        case let (.none, .some(legacy)): return legacy
        case (.none, .none):
            if let v2Error { throw v2Error }
            return (nil, [])
        }
    }

    private func loadV2Today(
        session: UserSession,
        dateKey: String
    ) async throws -> (BurnerListRow, [BurnerTaskRow])? {
        let listData = try await get(
            "burner_lists_v2?select=*&date_key=eq.\(dateKey)&deleted_at=is.null&order=updated_at.desc&limit=1",
            session: session
        )
        let lists = try JSONDecoder.supabase.decode([BurnerListRow].self, from: listData)
        let v2Snapshot: (BurnerListRow, [BurnerTaskRow])?
        if let list = lists.first {
            // Keep the first native client compatible with databases where
            // the scheduling migration has not been deployed yet.
            let taskData = try await get(
                "burner_tasks_v2?select=user_id,id,list_key,zone,text,done,sort_order,in_progress,board_order,scheduled_date,completed_at,updated_at,deleted_at&list_key=eq.\(list.key)&deleted_at=is.null&order=zone.asc,sort_order.asc",
                session: session
            )
            v2Snapshot = (list, try JSONDecoder.supabase.decode([BurnerTaskRow].self, from: taskData))
        } else {
            v2Snapshot = nil
        }

        return v2Snapshot
    }

    func ensureList(session: UserSession, dateKey: String) async throws {
        let row = BurnerListRow(
            userId: session.user.id, key: dateKey, dateKey: dateKey,
            frontName: "", backName: "", quote: "", updatedAt: Date(), deletedAt: nil
        )
        _ = try await write("burner_lists_v2?on_conflict=user_id,key", value: row, session: session)
        let legacy = LegacyListWrite(
            userId: session.user.id,
            dateKey: dateKey,
            state: LegacyState.empty(date: dateKey)
        )
        _ = try await write(
            "burner_lists?on_conflict=user_id,date_key",
            value: legacy,
            session: session
        )
    }

    func ensureInbox(session: UserSession, todayKey: String) async throws {
        let row = BurnerListRow(
            userId: session.user.id, key: "__inbox__", dateKey: todayKey,
            frontName: "", backName: "", quote: "", updatedAt: Date(), deletedAt: nil
        )
        _ = try await write("burner_lists_v2?on_conflict=user_id,key", value: row, session: session)
        let legacy = LegacyListWrite(
            userId: session.user.id,
            dateKey: "__inbox__",
            state: LegacyState.empty(date: todayKey)
        )
        _ = try await write("burner_lists?on_conflict=user_id,date_key", value: legacy, session: session)
    }

    func saveTask(_ task: BurnerTaskRow, session: UserSession) async throws {
        do {
            _ = try await write("burner_tasks_v2?on_conflict=user_id,id", value: task, session: session)
        } catch let error as ServiceError where error.message.contains("scheduled_date") || error.message.contains("completed_at") {
            // Temporary compatibility path until
            // 20260731120000_add_task_scheduling.sql is deployed.
            _ = try await write(
                "burner_tasks_v2?on_conflict=user_id,id",
                value: LegacyTaskWrite(task: task),
                session: session
            )
        }
        try await saveTaskToLegacy(task, session: session)
    }

    func updateTask(_ task: BurnerTaskRow, previousListKey: String, session: UserSession) async throws {
        if previousListKey != task.listKey {
            try await removeTaskFromLegacy(task.id, listKey: previousListKey, session: session)
        }
        try await saveTask(task, session: session)
    }

    func deleteTask(_ task: BurnerTaskRow, session: UserSession) async throws {
        var tombstone = task
        tombstone.updatedAt = Date()
        tombstone.deletedAt = tombstone.updatedAt
        do {
            _ = try await write("burner_tasks_v2?on_conflict=user_id,id", value: tombstone, session: session)
        } catch let error as ServiceError where error.message.contains("scheduled_date") || error.message.contains("completed_at") {
            _ = try await write(
                "burner_tasks_v2?on_conflict=user_id,id",
                value: LegacyTaskWrite(task: tombstone),
                session: session
            )
        }
        try await removeTaskFromLegacy(task.id, listKey: task.listKey, session: session)
    }

    private func get(_ path: String, session: UserSession) async throws -> Data {
        let request = request(path: path, method: "GET", session: session)
        let (data, response) = try await client.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func write<T: Encodable>(_ path: String, value: T, session: UserSession) async throws -> Data {
        var request = request(path: path, method: "POST", session: session)
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.supabase.encode(value)
        let (data, response) = try await client.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func request(path: String, method: String, session: UserSession) -> URLRequest {
        let url = URL(string: "\(configuration.supabaseURL.absoluteString)/rest/v1/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(configuration.anonymousKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func loadLegacyToday(
        session: UserSession,
        dateKey: String
    ) async throws -> (BurnerListRow, [BurnerTaskRow])? {
        let data = try await get("burner_lists?select=date_key,state", session: session)
        let rows = try JSONDecoder.supabase.decode([LegacyListEnvelope].self, from: data)
        guard let row = rows
            .filter({ $0.state.date == dateKey && $0.state.deleted != true })
            .max(by: { $0.state.updatedAt < $1.state.updatedAt })
        else { return nil }
        return row.nativeSnapshot(userId: session.user.id)
    }

    private func saveTaskToLegacy(_ task: BurnerTaskRow, session: UserSession) async throws {
        let data = try await get(
            "burner_lists?select=date_key,state&date_key=eq.\(task.listKey)&limit=1",
            session: session
        )
        guard var row = try JSONDecoder.supabase.decode([LegacyListEnvelope].self, from: data).first else {
            return
        }
        row.state.upsert(task)
        let payload = LegacyListWrite(
            userId: session.user.id,
            dateKey: row.dateKey,
            state: row.state
        )
        _ = try await write(
            "burner_lists?on_conflict=user_id,date_key",
            value: payload,
            session: session
        )
    }

    private func removeTaskFromLegacy(_ taskId: String, listKey: String, session: UserSession) async throws {
        let data = try await get(
            "burner_lists?select=date_key,state&date_key=eq.\(listKey)&limit=1",
            session: session
        )
        guard var row = try JSONDecoder.supabase.decode([LegacyListEnvelope].self, from: data).first else {
            return
        }
        guard row.state.removeTask(id: taskId) else { return }
        let payload = LegacyListWrite(userId: session.user.id, dateKey: row.dateKey, state: row.state)
        _ = try await write("burner_lists?on_conflict=user_id,date_key", value: payload, session: session)
    }
}

private struct LegacyListEnvelope: Codable {
    let dateKey: String
    var state: LegacyState

    enum CodingKeys: String, CodingKey {
        case dateKey = "date_key"
        case state
    }

    func nativeSnapshot(userId: UUID) -> (BurnerListRow, [BurnerTaskRow]) {
        let list = nativeList(userId: userId)
        return (list, state.nativeTasks(userId: userId, listKey: dateKey))
    }

    func nativeList(userId: UUID) -> BurnerListRow {
        BurnerListRow(
            userId: userId,
            key: dateKey,
            dateKey: state.date,
            frontName: state.front.name,
            backName: state.back.name,
            quote: state.quote,
            updatedAt: state.updatedAt,
            deletedAt: nil
        )
    }
}

private struct LegacyListWrite: Encodable {
    let userId: UUID
    let dateKey: String
    let state: LegacyState

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case dateKey = "date_key"
        case state
    }
}

private struct LegacyState: Codable {
    var date: String
    var front: LegacyZone
    var back: LegacyZone
    var sink: LegacyZone
    var unscheduled: [LegacyTask]
    var quote: String
    var meta: LegacyMeta?
    var deleted: Bool?

    enum CodingKeys: String, CodingKey {
        case date, unscheduled, quote
        case front = "front-burner"
        case back = "back-burner"
        case sink = "kitchen-sink"
        case meta = "_meta"
        case deleted = "_deleted"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        date = try values.decodeIfPresent(String.self, forKey: .date) ?? ""
        front = try values.decodeIfPresent(LegacyZone.self, forKey: .front) ?? .empty
        back = try values.decodeIfPresent(LegacyZone.self, forKey: .back) ?? .empty
        sink = try values.decodeIfPresent(LegacyZone.self, forKey: .sink) ?? .empty
        unscheduled = try values.decodeIfPresent([LegacyTask].self, forKey: .unscheduled) ?? []
        quote = try values.decodeIfPresent(String.self, forKey: .quote) ?? ""
        meta = try values.decodeIfPresent(LegacyMeta.self, forKey: .meta)
        deleted = try values.decodeIfPresent(Bool.self, forKey: .deleted)
    }

    init(
        date: String,
        front: LegacyZone,
        back: LegacyZone,
        sink: LegacyZone,
        unscheduled: [LegacyTask],
        quote: String,
        meta: LegacyMeta?,
        deleted: Bool?
    ) {
        self.date = date
        self.front = front
        self.back = back
        self.sink = sink
        self.unscheduled = unscheduled
        self.quote = quote
        self.meta = meta
        self.deleted = deleted
    }

    var updatedAt: Date { meta?.updatedAt ?? .distantPast }

    static func empty(date: String) -> LegacyState {
        LegacyState(
            date: date,
            front: LegacyZone(name: "", tasks: []),
            back: LegacyZone(name: "", tasks: []),
            sink: LegacyZone(name: "", tasks: []),
            unscheduled: [],
            quote: "",
            meta: LegacyMeta(updatedAt: Date(), deviceId: "ios-native", zone: nil, order: nil, doing: nil, boardOrder: nil, completedAt: nil),
            deleted: nil
        )
    }

    func nativeTasks(userId: UUID, listKey: String) -> [BurnerTaskRow] {
        let groups: [(BurnerZone, [LegacyTask])] = [
            (.front, front.tasks), (.back, back.tasks), (.sink, sink.tasks),
            (.unscheduled, unscheduled)
        ]
        return groups.flatMap { zone, tasks in
            tasks.enumerated().map { index, task in
                task.native(userId: userId, listKey: listKey, zone: zone, index: index, date: date)
            }
        }
    }

    mutating func upsert(_ task: BurnerTaskRow) {
        front.tasks.removeAll { $0.id == task.id }
        back.tasks.removeAll { $0.id == task.id }
        sink.tasks.removeAll { $0.id == task.id }
        unscheduled.removeAll { $0.id == task.id }
        let legacy = LegacyTask(task)
        switch task.zone {
        case .front: front.tasks.append(legacy)
        case .back: back.tasks.append(legacy)
        case .sink: sink.tasks.append(legacy)
        case .unscheduled: unscheduled.append(legacy)
        }
        meta = LegacyMeta(updatedAt: task.updatedAt, deviceId: "ios-native", zone: nil, order: nil, doing: nil, boardOrder: nil, completedAt: nil)
    }

    mutating func removeTask(id: String) -> Bool {
        let previousCount = front.tasks.count + back.tasks.count + sink.tasks.count + unscheduled.count
        front.tasks.removeAll { $0.id == id }
        back.tasks.removeAll { $0.id == id }
        sink.tasks.removeAll { $0.id == id }
        unscheduled.removeAll { $0.id == id }
        let changed = previousCount != front.tasks.count + back.tasks.count + sink.tasks.count + unscheduled.count
        if changed {
            meta = LegacyMeta(updatedAt: Date(), deviceId: "ios-native", zone: nil, order: nil, doing: nil, boardOrder: nil, completedAt: nil)
        }
        return changed
    }
}

private struct LegacyZone: Codable {
    var name: String
    var tasks: [LegacyTask]

    static let empty = LegacyZone(name: "", tasks: [])

    private enum CodingKeys: String, CodingKey { case name, tasks }

    init(name: String, tasks: [LegacyTask]) {
        self.name = name
        self.tasks = tasks
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? ""
        tasks = try values.decodeIfPresent([LegacyTask].self, forKey: .tasks) ?? []
    }
}

private struct LegacyTask: Codable {
    var id: String?
    var text: String
    var done: Bool
    var meta: LegacyMeta?

    enum CodingKeys: String, CodingKey {
        case id, text, done
        case meta = "_meta"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        text = try values.decodeIfPresent(String.self, forKey: .text) ?? ""
        done = try values.decodeIfPresent(Bool.self, forKey: .done) ?? false
        meta = try values.decodeIfPresent(LegacyMeta.self, forKey: .meta)
    }

    init(_ task: BurnerTaskRow) {
        id = task.id
        text = task.text
        done = task.done
        meta = LegacyMeta(
            updatedAt: task.updatedAt,
            deviceId: "ios-native",
            zone: task.zone.rawValue,
            order: task.sortOrder,
            doing: task.inProgress,
            boardOrder: task.boardOrder,
            completedAt: task.completedAt
        )
    }

    func native(userId: UUID, listKey: String, zone: BurnerZone, index: Int, date: String) -> BurnerTaskRow {
        BurnerTaskRow(
            userId: userId,
            id: id ?? "legacy-\(listKey)-\(zone.rawValue)-\(index)",
            listKey: listKey,
            zone: zone,
            text: text,
            done: done,
            sortOrder: meta?.order ?? Double(index),
            inProgress: meta?.doing ?? false,
            boardOrder: meta?.boardOrder ?? Double(index),
            scheduledDate: listKey == "__inbox__" ? nil : date,
            completedAt: meta?.completedAt,
            updatedAt: meta?.updatedAt ?? .distantPast,
            deletedAt: nil
        )
    }
}

private struct LegacyMeta: Codable {
    var updatedAt: Date?
    var deviceId: String?
    var zone: String?
    var order: Double?
    var doing: Bool?
    var boardOrder: Double?
    var completedAt: Date?
}

private struct LegacyTaskWrite: Encodable {
    let userId: UUID
    let id: String
    let listKey: String
    let zone: BurnerZone
    let text: String
    let done: Bool
    let sortOrder: Double
    let inProgress: Bool
    let boardOrder: Double
    let updatedAt: Date
    let deletedAt: Date?

    init(task: BurnerTaskRow) {
        userId = task.userId
        id = task.id
        listKey = task.listKey
        zone = task.zone
        text = task.text
        done = task.done
        sortOrder = task.sortOrder
        inProgress = task.inProgress
        boardOrder = task.boardOrder
        updatedAt = task.updatedAt
        deletedAt = task.deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, zone, text, done
        case userId = "user_id"
        case listKey = "list_key"
        case sortOrder = "sort_order"
        case inProgress = "in_progress"
        case boardOrder = "board_order"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

extension SupabaseBurnerRepository {
    func loadLists(session: UserSession) async throws -> [BurnerListRow] {
        var snapshots: [String: BurnerListRow] = [:]
        do {
            let data = try await get(
                "burner_lists_v2?select=*&deleted_at=is.null&order=date_key.desc,updated_at.desc",
                session: session
            )
            for row in try JSONDecoder.supabase.decode([BurnerListRow].self, from: data) {
                snapshots[row.key] = row
            }
        } catch {
            // A legacy deployment can legitimately have no usable v2 schema.
        }

        let legacyData = try await get("burner_lists?select=date_key,state", session: session)
        let legacyRows = try JSONDecoder.supabase.decode([LegacyListEnvelope].self, from: legacyData)
        for envelope in legacyRows where envelope.state.deleted != true {
            let row = envelope.nativeList(userId: session.user.id)
            if snapshots[row.key] == nil || row.updatedAt > snapshots[row.key]!.updatedAt {
                snapshots[row.key] = row
            }
        }
        return snapshots.values.sorted {
            if $0.dateKey != $1.dateKey { return $0.dateKey > $1.dateKey }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func loadList(
        session: UserSession,
        key: String
    ) async throws -> (BurnerListRow?, [BurnerTaskRow]) {
        var v2: (BurnerListRow, [BurnerTaskRow])?
        do {
            let listData = try await get(
                "burner_lists_v2?select=*&key=eq.\(key)&deleted_at=is.null&limit=1",
                session: session
            )
            if let list = try JSONDecoder.supabase.decode([BurnerListRow].self, from: listData).first {
                let taskData = try await get(
                    "burner_tasks_v2?select=user_id,id,list_key,zone,text,done,sort_order,in_progress,board_order,scheduled_date,completed_at,updated_at,deleted_at&list_key=eq.\(key)&deleted_at=is.null&order=zone.asc,sort_order.asc",
                    session: session
                )
                v2 = (list, try JSONDecoder.supabase.decode([BurnerTaskRow].self, from: taskData))
            }
        } catch {
            v2 = nil
        }

        let data = try await get(
            "burner_lists?select=date_key,state&date_key=eq.\(key)&limit=1",
            session: session
        )
        let legacyEnvelope = try JSONDecoder.supabase.decode([LegacyListEnvelope].self, from: data).first
        let legacy = legacyEnvelope.flatMap { envelope in
            envelope.state.deleted == true ? nil : envelope.nativeSnapshot(userId: session.user.id)
        }
        switch (v2, legacy) {
        case let (.some(v2), .some(legacy)): return legacy.0.updatedAt > v2.0.updatedAt ? legacy : v2
        case let (.some(v2), .none): return v2
        case let (.none, .some(legacy)): return legacy
        case (.none, .none): return (nil, [])
        }
    }
}
