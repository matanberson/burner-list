import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn(UserSession)
    }

    @Published private(set) var state: State = .restoring
    @Published var message: String?

    let auth: AuthService
    let repository: BurnerRepository
    private let oauthPresenter: OAuthPresenter

    init(auth: AuthService, repository: BurnerRepository, oauthPresenter: OAuthPresenter) {
        self.auth = auth
        self.repository = repository
        self.oauthPresenter = oauthPresenter
    }

    static func live() -> AppSession {
        let configuration = AppConfiguration.load()
        let auth = AuthService(configuration: configuration, store: KeychainSessionStore())
        return AppSession(
            auth: auth,
            repository: SupabaseBurnerRepository(configuration: configuration),
            oauthPresenter: OAuthPresenter()
        )
    }

    func restoreSession() async {
        guard let session = await auth.restoreSession() else {
            state = .signedOut
            return
        }
        state = .signedIn(session)
    }

    func signIn(email: String, password: String) async {
        await authenticate { try await auth.signIn(email: email, password: password) }
    }

    func signUp(email: String, password: String) async {
        await authenticate { try await auth.signUp(email: email, password: password) }
    }

    func signInWithGoogle() async {
        await authenticate {
            let url = try await auth.googleOAuthURL()
            let callback = try await oauthPresenter.authenticate(at: url)
            return try await auth.session(fromOAuthCallback: callback)
        }
    }

    func signOut() async {
        if case let .signedIn(session) = state { await auth.signOut(session: session) }
        state = .signedOut
    }

    private func authenticate(_ operation: () async throws -> UserSession) async {
        message = nil
        do {
            state = .signedIn(try await operation())
        } catch {
            state = .signedOut
            message = error.localizedDescription
        }
    }
}
