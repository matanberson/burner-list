import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppSession

    var body: some View {
        ZStack {
            BurnerTheme.paper.ignoresSafeArea()

            switch app.state {
            case .restoring:
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(BurnerTheme.textMid)
                    Text("Opening Burner List…")
                        .font(BurnerTheme.body(14))
                        .foregroundStyle(BurnerTheme.textSoft)
                }
            case .signedOut:
                AuthenticationView()
            case let .signedIn(session):
                TodayView(session: session, repository: app.repository)
            }
        }
        .preferredColorScheme(.light)
    }
}
