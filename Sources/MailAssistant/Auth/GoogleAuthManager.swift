import Foundation
import GoogleSignIn

@MainActor
final class GoogleAuthManager: ObservableObject {
    static let shared = GoogleAuthManager()

    @Published var isSignedIn = false
    @Published var userEmail: String = ""
    @Published var userName: String = ""

    private init() {
        restoreSession()
    }

    // MARK: - Sign In

    func signIn(presenting viewController: UIViewController) async throws {
        let scopes = [
            "https://www.googleapis.com/auth/gmail.modify",
            "https://www.googleapis.com/auth/calendar.events",
        ]

        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: viewController,
            hint: nil,
            additionalScopes: scopes
        )

        isSignedIn = true
        userEmail = result.user.profile?.email ?? ""
        userName = result.user.profile?.name ?? ""
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        userEmail = ""
        userName = ""
    }

    // MARK: - Token

    func accessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw AuthError.notSignedIn
        }
        try await user.refreshTokensIfNeeded()
        guard let token = user.accessToken.tokenString as String? else {
            throw AuthError.tokenUnavailable
        }
        return token
    }

    // MARK: - Private

    private func restoreSession() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            guard let self, let user else { return }
            Task { @MainActor in
                self.isSignedIn = true
                self.userEmail = user.profile?.email ?? ""
                self.userName = user.profile?.name ?? ""
            }
        }
    }
}

enum AuthError: LocalizedError {
    case notSignedIn
    case tokenUnavailable

    var errorDescription: String? {
        switch self {
        case .notSignedIn:      return "You are not signed in to Google."
        case .tokenUnavailable: return "Could not retrieve access token."
        }
    }
}
