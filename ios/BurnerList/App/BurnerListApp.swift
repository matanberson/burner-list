import SwiftUI

@main
struct BurnerListApp: App {
    @StateObject private var session = AppSession.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .task { await session.restoreSession() }
        }
    }
}
