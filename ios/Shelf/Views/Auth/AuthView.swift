import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @State private var showSignUp = false
    @State private var showSignIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background: hero image or gradient fallback
                heroBackground

                // Gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.3),
                        Color.black.opacity(0.7),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    Spacer()

                    // Wordmark + tagline
                    VStack(spacing: ShelfSpacing.sm) {
                        Text("Shelf")
                            .font(ShelfFonts.displayLarge)
                            .foregroundStyle(.white)

                        Text("Track what you read.\nSee what friends are reading.")
                            .font(ShelfFonts.bodySerif)
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                    Spacer()

                    // Auth buttons
                    VStack(spacing: ShelfSpacing.md) {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                        } onCompletion: { result in
                            handleAppleSignIn(result)
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.cover))

                        // Sign up with email
                        Button {
                            showSignUp = true
                        } label: {
                            Text("Sign up with Email")
                                .font(ShelfFonts.bodySansBold)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .foregroundStyle(.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ShelfRadius.cover)
                                        .stroke(.white.opacity(0.6), lineWidth: 1.5)
                                )
                        }

                        // Sign in link
                        Button {
                            showSignIn = true
                        } label: {
                            Text("Already have an account? **Sign in**")
                                .font(ShelfFonts.subheadlineSans)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.top, ShelfSpacing.xxs)
                    }
                    .padding(.horizontal, ShelfSpacing.xxl)
                    .padding(.bottom, ShelfSpacing.huge)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $showSignIn) {
                LoginView()
            }
        }
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let _ = UIImage(named: "LibraryHero") {
            Image("LibraryHero")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        } else {
            // Gradient fallback when no hero image is set
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.12, blue: 0.10),
                    Color(red: 0.08, green: 0.06, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
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
