import AuthenticationServices
import UIKit

@MainActor
final class OAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var webSession: ASWebAuthenticationSession?

    func authenticate(at url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "burnerlist"
            ) { [weak self] callbackURL, error in
                self?.webSession = nil
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? OAuthError.missingCallback)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            webSession = session
            guard session.start() else {
                webSession = nil
                continuation.resume(throwing: OAuthError.couldNotStart)
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

enum OAuthError: LocalizedError {
    case couldNotStart
    case missingCallback
    case invalidCallback(String)

    var errorDescription: String? {
        switch self {
        case .couldNotStart: "Could not open Google sign-in."
        case .missingCallback: "Google sign-in did not return to Burner List."
        case let .invalidCallback(message): message
        }
    }
}
