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
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "books.vertical.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Shelf")
                .font(.largeTitle.bold())

            Text("Track what you read. Discover what your friends are reading. Share your reviews.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onNext()
            } label: {
                Text("Get Started")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Bring Your Books")
                .font(.title2.bold())

            Text("Import your library from Goodreads or StoryGraph. Your ratings, reviews, and shelves come with you.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showImport = true
                } label: {
                    Text("Import Library")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Skip for now", action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
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
    @State private var contactMatches: [User] = []
    @State private var followedIDs: Set<UUID> = []
    @State private var isLoading = false
    @State private var isSyncingContacts = false
    @State private var hasTriedContacts = false

    private let contactsService = ContactsService.shared

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)

                Text("Find Readers")
                    .font(.title2.bold())

                Text("Follow people to build your feed. We'll suggest readers with similar taste.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)

            // Contacts sync button
            if !hasTriedContacts {
                Button {
                    syncContacts()
                } label: {
                    HStack(spacing: 8) {
                        if isSyncingContacts {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "person.crop.rectangle.stack")
                        }
                        Text("Find Friends from Contacts")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isSyncingContacts)
                .padding(.horizontal, 24)
            }

            // User list
            if isLoading && allUsers.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if allUsers.isEmpty {
                Spacer()
                Text("Suggestions will appear after you import or rate some books.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !contactMatches.isEmpty {
                            Text("From Your Contacts")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }

                        ForEach(contactMatches) { user in
                            SuggestedUserRow(
                                user: user,
                                isFollowed: followedIDs.contains(user.id)
                            ) {
                                toggleFollow(user)
                            }
                            Divider().padding(.horizontal)
                        }

                        if !suggestedUsers.isEmpty {
                            Text("Suggested for You")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }

                        ForEach(suggestedUsers) { user in
                            SuggestedUserRow(
                                user: user,
                                isFollowed: followedIDs.contains(user.id)
                            ) {
                                toggleFollow(user)
                            }
                            Divider().padding(.horizontal)
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                Button {
                    onNext()
                } label: {
                    Text(followedIDs.isEmpty ? "Continue" : "Continue (\(followedIDs.count) following)")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if !allUsers.isEmpty {
                    Button("Skip", action: onSkip)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .task {
            await loadSuggestions()
        }
    }

    private var allUsers: [User] {
        contactMatches + suggestedUsers
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

    private func syncContacts() {
        Task {
            isSyncingContacts = true
            let granted = await contactsService.requestAccess()
            if granted {
                do {
                    let matched = try await contactsService.syncContacts()
                    // Filter out anyone already in suggestions
                    let suggestedIDs = Set(suggestedUsers.map(\.id))
                    contactMatches = matched.filter { !suggestedIDs.contains($0.id) }
                } catch {
                    // Contacts sync failed — continue without
                }
            }
            hasTriedContacts = true
            isSyncingContacts = false
        }
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
        HStack(spacing: 12) {
            UserAvatarView(url: user.avatarURL, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.subheadline.weight(.semibold))
                if let displayName = user.displayName {
                    Text(displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onToggle) {
                Text(isFollowed ? "Following" : "Follow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isFollowed ? Color(.systemGray5) : Color.accentColor)
                    .foregroundStyle(isFollowed ? Color.primary : Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Step 4: Enable Notifications

private struct NotificationStep: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Stay in the Loop")
                .font(.title2.bold())

            Text("Get notified when friends finish books or when your import is complete. We keep it minimal — no spam.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    enableNotifications()
                } label: {
                    Text("Enable Notifications")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Maybe Later") {
                    onComplete()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
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
