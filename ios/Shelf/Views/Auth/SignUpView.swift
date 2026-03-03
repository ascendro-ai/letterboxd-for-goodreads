import SwiftUI

struct SignUpView: View {
    @Environment(AuthService.self) private var auth
    @FocusState private var focusedField: Field?

    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private enum Field { case username, email, password }

    private var isFormValid: Bool {
        !email.isEmpty && password.count >= 8 && !username.isEmpty && username.count >= 3
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ShelfSpacing.xxxl) {
                // Header
                VStack(spacing: ShelfSpacing.sm) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 40))
                        .foregroundStyle(ShelfColors.accent)

                    Text("Create your account")
                        .font(ShelfFonts.displaySmall)
                        .foregroundStyle(ShelfColors.textPrimary)

                    Text("Start tracking your reading journey")
                        .font(ShelfFonts.subheadlineSans)
                        .foregroundStyle(ShelfColors.textSecondary)
                }
                .padding(.top, ShelfSpacing.huge)

                // Fields
                VStack(spacing: ShelfSpacing.lg) {
                    authField(
                        label: "Username",
                        icon: "at",
                        field: .username,
                        hint: usernameHint
                    ) {
                        TextField("choose a username", text: $username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .username)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .email }
                    }

                    authField(
                        label: "Email",
                        icon: "envelope",
                        field: .email,
                        hint: nil
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
                        field: .password,
                        hint: passwordHint
                    ) {
                        SecureField("8+ characters", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { if isFormValid { signUp() } }
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

                // Create Account button
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
                }
                .disabled(isLoading || !isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)

                // Terms
                Text("By creating an account, you agree to our Terms of Service and Privacy Policy.")
                    .font(ShelfFonts.caption2)
                    .foregroundStyle(ShelfColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, ShelfSpacing.lg)

                Spacer()
            }
            .padding(.horizontal, ShelfSpacing.xxl)
        }
        .background(ShelfColors.background)
        .navigationTitle("Create Account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .username }
    }

    // MARK: - Hints

    private var usernameHint: AuthFieldHint? {
        guard !username.isEmpty, username.count < 3 else { return nil }
        return AuthFieldHint(text: "At least 3 characters", color: ShelfColors.amber)
    }

    private var passwordHint: AuthFieldHint? {
        guard !password.isEmpty, password.count < 8 else { return nil }
        return AuthFieldHint(text: "At least 8 characters", color: ShelfColors.amber)
    }

    // MARK: - Field Builder

    @ViewBuilder
    private func authField<Content: View>(
        label: String,
        icon: String,
        field: Field,
        hint: AuthFieldHint?,
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

            if let hint {
                Text(hint.text)
                    .font(ShelfFonts.caption)
                    .foregroundStyle(hint.color)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func signUp() {
        isLoading = true
        errorMessage = nil
        focusedField = nil

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

// MARK: - Auth Field Hint

private struct AuthFieldHint {
    let text: String
    let color: Color
}
