import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            VStack(spacing: ShelfSpacing.lg) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .shelfTextField()

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .shelfTextField()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.error)
            }

            Button {
                signIn()
            } label: {
                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                    }
                }
                .shelfPrimaryButton()
            }
            .disabled(isLoading || email.isEmpty || password.isEmpty)

            Spacer()
        }
        .padding(ShelfSpacing.xxl)
        .background(ShelfColors.background)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.large)
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await auth.signIn(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
