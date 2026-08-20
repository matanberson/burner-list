import Foundation
import Security

struct UserSession: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: TimeInterval
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }
}

struct AuthUser: Codable, Equatable, Sendable {
    let id: UUID
    let email: String?
}

protocol SessionStore: Sendable {
    func load() -> UserSession?
    func save(_ session: UserSession)
    func clear()
}

final class KeychainSessionStore: SessionStore, @unchecked Sendable {
    private let service = "com.matan.burnerlist.auth"
    private let account = "supabase-session"

    func load() -> UserSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(UserSession.self, from: data)
    }

    func save(_ session: UserSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        clear()
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary, nil)
    }

    func clear() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }
}

actor AuthService {
    private let configuration: AppConfiguration
    private let store: SessionStore
    private let client: URLSession

    init(configuration: AppConfiguration, store: SessionStore, client: URLSession = .shared) {
        self.configuration = configuration
        self.store = store
        self.client = client
    }

    func restoreSession() async -> UserSession? {
        guard let session = store.load() else { return nil }
        if session.expiresAt > Date().timeIntervalSince1970 + 60 { return session }
        return try? await refresh(session.refreshToken)
    }

    func signIn(email: String, password: String) async throws -> UserSession {
        try await token(path: "token?grant_type=password", body: ["email": email, "password": password])
    }

    func signUp(email: String, password: String) async throws -> UserSession {
        try await token(
            path: "signup",
            body: ["email": email, "password": password],
            missingSessionMessage: "Check your email to confirm your account, then sign in."
        )
    }

    func googleOAuthURL() throws -> URL {
        var components = URLComponents(
            url: configuration.supabaseURL.appendingPathComponent("auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: "burnerlist://auth-callback")
        ]
        guard let url = components?.url else {
            throw OAuthError.couldNotStart
        }
        return url
    }

    func session(fromOAuthCallback callback: URL) async throws -> UserSession {
        let values = try oauthValues(from: callback)
        if let description = values["error_description"] ?? values["error"] {
            throw OAuthError.invalidCallback(description.replacingOccurrences(of: "+", with: " "))
        }
        guard
            let accessToken = values["access_token"],
            let refreshToken = values["refresh_token"]
        else {
            throw OAuthError.invalidCallback("Google sign-in returned no session.")
        }
        let user = try await loadUser(accessToken: accessToken)
        let expiresIn = TimeInterval(values["expires_in"] ?? "3600") ?? 3600
        let session = UserSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().timeIntervalSince1970 + expiresIn,
            user: user
        )
        store.save(session)
        return session
    }

    func refresh(_ token: String) async throws -> UserSession {
        try await self.token(path: "token?grant_type=refresh_token", body: ["refresh_token": token])
    }

    func signOut(session: UserSession) async {
        var request = request(path: "logout", method: "POST")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await client.data(for: request)
        store.clear()
    }

    private func token(
        path: String,
        body: [String: String],
        missingSessionMessage: String = "No session was returned. Please try signing in again."
    ) async throws -> UserSession {
        var request = request(path: path, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await client.data(for: request)
        try validate(response: response, data: data)
        let payload = try JSONDecoder().decode(AuthPayload.self, from: data)
        guard let session = payload.session else { throw ServiceError(message: missingSessionMessage) }
        store.save(session)
        return session
    }

    private func request(path: String, method: String) -> URLRequest {
        let url = URL(string: "\(configuration.supabaseURL.absoluteString)/auth/v1/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        // Do not leave app launch or authentication waiting on an unreachable network.
        request.timeoutInterval = 15
        request.setValue(configuration.anonymousKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func loadUser(accessToken: String) async throws -> AuthUser {
        var request = request(path: "user", method: "GET")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await client.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(AuthUser.self, from: data)
    }

    private func oauthValues(from callback: URL) throws -> [String: String] {
        let encoded = callback.fragment ?? callback.query ?? ""
        guard let components = URLComponents(string: "?\(encoded)") else {
            throw OAuthError.invalidCallback("Google sign-in returned an invalid callback.")
        }
        return Dictionary(uniqueKeysWithValues: components.queryItems?.compactMap { item in
            item.value.map { (item.name, $0) }
        } ?? [])
    }
}

private struct AuthPayload: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: TimeInterval?
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
        case user
    }

    var session: UserSession? {
        guard let accessToken, let refreshToken, let expiresAt else { return nil }
        return UserSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            user: user
        )
    }
}

struct ServiceError: LocalizedError, Decodable, Sendable {
    let message: String
    var errorDescription: String? { message }

    private enum CodingKeys: String, CodingKey {
        case message, msg
        case description = "error_description"
    }

    init(message: String) { self.message = message }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        message = try values.decodeIfPresent(String.self, forKey: .message)
            ?? values.decodeIfPresent(String.self, forKey: .msg)
            ?? values.decodeIfPresent(String.self, forKey: .description)
            ?? "The server could not complete the request."
    }
}

func validate(response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
        let error = (try? JSONDecoder().decode(ServiceError.self, from: data))
        throw error ?? ServiceError(message: "The server could not complete the request.")
    }
}
