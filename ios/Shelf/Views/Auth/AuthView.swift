import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                // Logo + tagline
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.accentColor)

                    Text("Shelf")
                        .font(.largeTitle.bold())

                    Text("Track what you read.\nSee what friends are reading.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.whiteOutline)
                    .frame(height: 50)

                    // Google Sign In
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "g.circle.fill")
                                .font(.title3)
                            Text("Sign in with Google")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemBackground))
                        .foregroundStyle(Color(.label))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                    }

                    Button {
                        showSignUp = true
                    } label: {
                        Text("Sign up with email")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    NavigationLink {
                        LoginView()
                    } label: {
                        Text("Already have an account? **Sign in**")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
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

    private func signInWithGoogle() {
        // TODO: Integrate Google Sign In SDK (GoogleSignIn-iOS)
        // 1. Add GoogleService-Info.plist to project
        // 2. Add GoogleSignIn SPM dependency
        // 3. Call GIDSignIn.sharedInstance.signIn(withPresenting:) to get idToken
        // 4. Pass idToken to AuthService.shared.signInWithGoogle(idToken:)
    }
}
