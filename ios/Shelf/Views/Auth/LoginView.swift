import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: ShelfSpacing.xxxl) {
                // Header
                VStack(spacing: ShelfSpacing.sm) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(ShelfColors.accent)

                    Text("Welcome back")
                        .font(ShelfFonts.displaySmall)
                        .foregroundStyle(ShelfColors.textPrimary)

                    Text("Sign in to continue reading")
                        .font(ShelfFonts.subheadlineSans)
                        .foregroundStyle(ShelfColors.textSecondary)
                }
                .padding(.top, ShelfSpacing.huge)

                // Fields
                VStack(spacing: ShelfSpacing.lg) {
                    authField(
                        label: "Email",
                        icon: "envelope",
                        field: .email
                    ) {
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    authField(
                        label: "Password",
                        icon: "lock",
                        field: .password
                    ) {
                        SecureField("Enter your password", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if canSignIn { signIn() } }
                    }
                }

                // Error
                if let errorMessage {
                    HStack(spacing: ShelfSpacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(errorMessage)
                    }
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.error)
                    .padding(ShelfSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ShelfColors.error.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.medium))
                }

                // Sign In button
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
                .disabled(isLoading || !canSignIn)
                .opacity(canSignIn ? 1.0 : 0.5)

                Spacer()
            }
            .padding(.horizontal, ShelfSpacing.xxl)
        }
        .background(ShelfColors.background)
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .email }
    }

    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty
    }

    @ViewBuilder
    private func authField<Content: View>(
        label: String,
        icon: String,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.xs) {
            Text(label)
                .font(ShelfFonts.captionBold)
                .foregroundStyle(ShelfColors.textSecondary)
                .textCase(.uppercase)

            HStack(spacing: ShelfSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(
                        focusedField == field ? ShelfColors.accent : ShelfColors.textTertiary
                    )
                    .frame(width: 20)

                content()
                    .font(ShelfFonts.bodySans)
            }
            .padding(.horizontal, ShelfSpacing.lg)
            .padding(.vertical, ShelfSpacing.md)
            .background(ShelfColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.cover))
            .overlay(
                RoundedRectangle(cornerRadius: ShelfRadius.cover)
                    .stroke(
                        focusedField == field ? ShelfColors.accent.opacity(0.5) : .clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField)
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil
        focusedField = nil

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
