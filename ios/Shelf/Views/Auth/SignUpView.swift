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
        VStack(spacing: ShelfSpacing.xxl) {
            VStack(spacing: ShelfSpacing.lg) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .shelfTextField()

                if !username.isEmpty && username.count < 3 {
                    Text("Username must be at least 3 characters")
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .shelfTextField()

                SecureField("Password (8+ characters)", text: $password)
                    .textContentType(.newPassword)
                    .shelfTextField()

                if !password.isEmpty && password.count < 8 {
                    Text("Password must be at least 8 characters")
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.amber)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.error)
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
                    }
                }
                .shelfPrimaryButton()
                .opacity(isFormValid ? 1.0 : 0.5)
            }
            .disabled(isLoading || !isFormValid)

            Spacer()
        }
        .padding(ShelfSpacing.xxl)
        .background(ShelfColors.background)
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
