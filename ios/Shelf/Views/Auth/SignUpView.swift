import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var usernameError: String? {
        guard !username.isEmpty else { return nil }
        if username.count < 3 {
            return "Username must be at least 3 characters"
        }
        if Self.reservedUsernames.contains(username.lowercased()) {
            return "This username is not available"
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if username.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Username can only contain letters, numbers, and underscores"
        }
        return nil
    }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && !username.isEmpty
        && username.count >= 3 && usernameError == nil && !inviteCode.isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let usernameError {
                    Text(usernameError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if !password.isEmpty && password.count < 8 {
                    Text("Password must be at least 8 characters")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Invite code field
                TextField("Invite code", text: $inviteCode)
                    .textContentType(.oneTimeCode)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Don't have an invite? Join the waitlist at shelf.app")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                signUp()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isLoading || !isFormValid)

            Spacer()
        }
        .padding(24)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.large)
    }

    private func signUp() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await auth.signUp(
                    email: email,
                    password: password,
                    username: username,
                    inviteCode: inviteCode
                )
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Reserved Usernames

    private static let reservedUsernames: Set<String> = [
        // App routes & features
        "admin", "administrator", "shelf", "shelfapp", "support", "help",
        "settings", "profile", "feed", "search", "log", "notifications",
        "explore", "discover", "trending", "popular", "home", "about",
        "terms", "privacy", "legal", "contact", "blog", "news",
        // System
        "api", "app", "www", "mail", "email", "root", "system",
        "null", "undefined", "anonymous", "mod", "moderator",
        // Social
        "everyone", "all", "public", "private", "official", "verified",
        "team", "staff", "bot", "test", "demo",
    ]
}
