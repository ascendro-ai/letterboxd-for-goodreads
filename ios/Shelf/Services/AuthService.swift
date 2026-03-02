import Foundation
import AuthenticationServices

// MARK: - Auth State

enum AuthState {
    case unknown
    case signedOut
    case signedIn(User)
}

// MARK: - Auth Service

@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var state: AuthState = .unknown
    private(set) var currentUser: User?

    private let api = APIClient.shared
    private let tokenKey = "shelf_auth_token"
    private let refreshTokenKey = "shelf_refresh_token"
    private let userKey = "shelf_current_user"

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    private init() {}

    // MARK: - Session Restore

    func restoreSession() async {
        guard let token = KeychainHelper.read(key: tokenKey),
              let refreshToken = KeychainHelper.read(key: refreshTokenKey) else {
            state = .signedOut
            return
        }

        api.authToken = token

        do {
            let user: User = try await api.request(.get, path: "/me")
            currentUser = user
            state = .signedIn(user)
        } catch {
            // Token expired — try refresh
            do {
                try await refresh(token: refreshToken)
            } catch {
                signOut()
            }
        }
    }

    // MARK: - Email + Password

    func signUp(email: String, password: String, username: String, inviteCode: String? = nil) async throws {
        let request = SignupRequest(email: email, password: password, username: username, inviteCode: inviteCode)
        let response: AuthResponse = try await api.request(.post, path: "/auth/signup", body: request)
        handleAuthResponse(response)
    }

    func signIn(email: String, password: String) async throws {
        let request = LoginRequest(email: email, password: password)
        let response: AuthResponse = try await api.request(.post, path: "/auth/login", body: request)
        handleAuthResponse(response)
    }

    // MARK: - Apple Sign In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw APIError.validationError("Invalid Apple credential")
        }

        let request = OAuthRequest(idToken: tokenString, username: nil)
        let response: AuthResponse = try await api.request(.post, path: "/auth/apple", body: request)
        handleAuthResponse(response)
    }

    // MARK: - Google Sign In
    // TODO: Integrate Google Sign In SDK when adding GoogleService-Info.plist

    func signInWithGoogle(idToken: String) async throws {
        let request = OAuthRequest(idToken: idToken, username: nil)
        let response: AuthResponse = try await api.request(.post, path: "/auth/google", body: request)
        handleAuthResponse(response)
    }

    // MARK: - Token Refresh

    func refresh(token: String) async throws {
        let request = RefreshRequest(refreshToken: token)
        let response: AuthResponse = try await api.request(.post, path: "/auth/refresh", body: request)
        handleAuthResponse(response)
    }

    // MARK: - Sign Out

    func signOut() {
        api.authToken = nil
        KeychainHelper.delete(key: tokenKey)
        KeychainHelper.delete(key: refreshTokenKey)
        KeychainHelper.delete(key: userKey)
        currentUser = nil
        state = .signedOut
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        try await api.request(.delete, path: "/auth/account")
        signOut()
    }

    // MARK: - Private

    private func handleAuthResponse(_ response: AuthResponse) {
        api.authToken = response.accessToken
        KeychainHelper.save(key: tokenKey, value: response.accessToken)
        KeychainHelper.save(key: refreshTokenKey, value: response.refreshToken)
        currentUser = response.user
        state = .signedIn(response.user)
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
