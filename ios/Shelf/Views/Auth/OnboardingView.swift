import SwiftUI
import Contacts

struct OnboardingView: View {
    @Environment(AuthService.self) private var auth
    @State private var currentStep = 0
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                WelcomeStep(onNext: { currentStep = 1 })
                    .tag(0)

                ImportStep(onNext: { currentStep = 2 }, onSkip: { currentStep = 2 })
                    .tag(1)

                FollowStep(onNext: { currentStep = 3 }, onSkip: { currentStep = 3 })
                    .tag(2)

                NotificationStep(onComplete: onComplete)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
            .background(ShelfColors.background)
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 72))
                .foregroundStyle(ShelfColors.accent)

            Text("Welcome to Shelf")
                .font(ShelfFonts.displayLarge)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Track what you read. Discover what your friends are reading. Share your reviews.")
                .font(ShelfFonts.bodySerif)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onNext()
            } label: {
                Text("Get Started")
                    .shelfPrimaryButton()
            }
            .padding(.horizontal, ShelfSpacing.xxl)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Step 2: Import Library

private struct ImportStep: View {
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var showImport = false

    var body: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            Spacer()

            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 56))
                .foregroundStyle(ShelfColors.accent)

            Text("Bring Your Books")
                .font(ShelfFonts.displayMedium)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Import your library from Goodreads or StoryGraph. Your ratings, reviews, and shelves come with you.")
                .font(ShelfFonts.bodySerif)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: ShelfSpacing.md) {
                Button {
                    showImport = true
                } label: {
                    Text("Import Library")
                        .shelfPrimaryButton()
                }

                Button("Skip for now", action: onSkip)
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textSecondary)
            }
            .padding(.horizontal, ShelfSpacing.xxl)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showImport) {
            ImportView()
        }
        .onChange(of: showImport) { _, isPresented in
            if !isPresented {
                onNext()
            }
        }
    }
}

// MARK: - Step 3: Find Friends

private struct FollowStep: View {
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var suggestedUsers: [User] = []
    @State private var followedIDs: Set<UUID> = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            VStack(spacing: ShelfSpacing.md) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ShelfColors.accent)

                Text("Find Readers")
                    .font(ShelfFonts.displayMedium)
                    .foregroundStyle(ShelfColors.textPrimary)

                Text("Follow people to build your feed. We'll suggest readers with similar taste.")
                    .font(ShelfFonts.bodySerif)
                    .foregroundStyle(ShelfColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(ShelfColors.accent)
                Spacer()
            } else if suggestedUsers.isEmpty {
                Spacer()
                Text("Suggestions will appear after you import or rate some books.")
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(suggestedUsers) { user in
                            SuggestedUserRow(
                                user: user,
                                isFollowed: followedIDs.contains(user.id)
                            ) {
                                toggleFollow(user)
                            }
                            ShelfDivider().padding(.horizontal)
                        }
                    }
                }
            }

            VStack(spacing: ShelfSpacing.md) {
                Button {
                    onNext()
                } label: {
                    Text(followedIDs.isEmpty ? "Continue" : "Continue (\(followedIDs.count) following)")
                        .shelfPrimaryButton()
                }

                if !suggestedUsers.isEmpty {
                    Button("Skip", action: onSkip)
                        .font(ShelfFonts.subheadlineSans)
                        .foregroundStyle(ShelfColors.textSecondary)
                }
            }
            .padding(.horizontal, ShelfSpacing.xxl)
            .padding(.bottom, 40)
        }
        .task {
            await loadSuggestions()
        }
    }

    private func loadSuggestions() async {
        isLoading = true
        do {
            let matches = try await SocialService.shared.getTasteMatches()
            suggestedUsers = matches.map(\.user)
        } catch {
            // No suggestions available — that's fine
        }
        isLoading = false
    }

    private func toggleFollow(_ user: User) {
        Task {
            if followedIDs.contains(user.id) {
                try? await SocialService.shared.unfollow(userID: user.id)
                followedIDs.remove(user.id)
            } else {
                try? await SocialService.shared.follow(userID: user.id)
                followedIDs.insert(user.id)
            }
        }
    }
}

struct SuggestedUserRow: View {
    let user: User
    let isFollowed: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: ShelfSpacing.md) {
            UserAvatarView(url: user.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(ShelfFonts.subheadlineBold)
                    .foregroundStyle(ShelfColors.textPrimary)
                if let displayName = user.displayName {
                    Text(displayName)
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.textSecondary)
                }
            }

            Spacer()

            Button(action: onToggle) {
                Text(isFollowed ? "Following" : "Follow")
                    .font(ShelfFonts.captionBold)
                    .padding(.horizontal, ShelfSpacing.md)
                    .padding(.vertical, ShelfSpacing.xs)
                    .background(isFollowed ? ShelfColors.backgroundTertiary : ShelfColors.accent)
                    .foregroundStyle(isFollowed ? ShelfColors.textPrimary : Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, ShelfSpacing.sm)
    }
}

// MARK: - Step 4: Enable Notifications

private struct NotificationStep: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(ShelfColors.accent)

            Text("Stay in the Loop")
                .font(ShelfFonts.displayMedium)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Get notified when friends finish books or when your import is complete. We keep it minimal — no spam.")
                .font(ShelfFonts.bodySerif)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: ShelfSpacing.md) {
                Button {
                    enableNotifications()
                } label: {
                    Text("Enable Notifications")
                        .shelfPrimaryButton()
                }

                Button("Maybe Later") {
                    onComplete()
                }
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
            }
            .padding(.horizontal, ShelfSpacing.xxl)
            .padding(.bottom, 40)
        }
    }

    private func enableNotifications() {
        Task {
            _ = await NotificationService.shared.requestAuthorization()
            onComplete()
        }
    }
}
