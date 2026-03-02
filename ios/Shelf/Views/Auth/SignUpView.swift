import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var auth

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && !username.isEmpty && username.count >= 3
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

                if !username.isEmpty && username.count < 3 {
                    Text("Username must be at least 3 characters")
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
                try await auth.signUp(email: email, password: password, username: username)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
