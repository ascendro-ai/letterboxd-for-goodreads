import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo + tagline
                VStack(spacing: ShelfSpacing.md) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(ShelfColors.accent)

                    Text("Shelf")
                        .font(ShelfFonts.displayLarge)
                        .foregroundStyle(ShelfColors.textPrimary)

                    Text("Track what you read.\nSee what friends are reading.")
                        .font(ShelfFonts.subheadlineSans)
                        .foregroundStyle(ShelfColors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: ShelfSpacing.md) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 50)

                    Button {
                        showSignUp = true
                    } label: {
                        Text("Sign up with email")
                            .shelfPrimaryButton()
                    }

                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("Already have an account? **Sign in**")
                            .font(ShelfFonts.subheadlineSans)
                            .foregroundStyle(ShelfColors.textSecondary)
                    }
                    .padding(.top, ShelfSpacing.xxs)
                }
                .padding(.horizontal, ShelfSpacing.xxl)
                .padding(.bottom, 40)
            }
            .background(ShelfColors.background)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    try? await AuthService.shared.signInWithApple(credential: credential)
                }
            }
        case .failure:
            break
        }
    }
}
