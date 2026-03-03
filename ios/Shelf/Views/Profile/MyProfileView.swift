import SwiftUI

struct MyProfileView: View {
    @State private var viewModel = ProfileViewModel()

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        ProfileContentView(viewModel: viewModel)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: ShelfSpacing.md) {
                        NavigationLink {
                            ReadingStatsView()
                        } label: {
                            Image(systemName: "chart.bar")
                        }
                        .accessibilityLabel("Reading Stats")

                        NavigationLink {
                            ReadingChallengeView()
                        } label: {
                            Image(systemName: "target")
                        }
                        .accessibilityLabel("\(String(currentYear)) Reading Challenge")

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
    }
}

struct UserProfileView: View {
    let userID: UUID
    @State private var viewModel: ProfileViewModel

    init(userID: UUID) {
        self.userID = userID
        self._viewModel = State(initialValue: ProfileViewModel(userID: userID))
    }

    var body: some View {
        ProfileContentView(viewModel: viewModel)
    }
}

struct ProfileContentView: View {
    @Bindable var viewModel: ProfileViewModel

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.profile == nil {
                LoadingStateView()
            } else if let error = viewModel.error, viewModel.profile == nil {
                ErrorStateView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if let profile = viewModel.profile {
                profileContent(profile)
            } else {
                // Fallback: no state matched — trigger load
                LoadingStateView()
                    .task { await viewModel.load() }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: ShelfSpacing.xl) {
                // Avatar + name
                VStack(spacing: ShelfSpacing.sm) {
                    UserAvatarView(url: profile.user.avatarURL, size: 80)

                    VStack(spacing: ShelfSpacing.xxs) {
                        if let displayName = profile.user.displayName {
                            Text(displayName)
                                .font(ShelfFonts.headlineSerif)
                        }
                        Text("@\(profile.user.username)")
                            .font(ShelfFonts.subheadlineSans)
                            .foregroundStyle(ShelfColors.textSecondary)
                    }

                    if let bio = profile.user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(ShelfFonts.captionSerif)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, ShelfSpacing.xxxl)
                    }
                }

                // Stats
                HStack(spacing: ShelfSpacing.xxxl) {
                    StatColumn(value: profile.booksCount, label: "Books")
                    StatColumn(value: profile.followersCount, label: "Followers")
                    StatColumn(value: profile.followingCount, label: "Following")
                }

                // Follow button (for other users)
                if !viewModel.isOwnProfile {
                    Button {
                        Task { try? await viewModel.toggleFollow() }
                    } label: {
                        Text(profile.isFollowing == true ? "Following" : "Follow")
                            .font(ShelfFonts.subheadlineBold)
                            .frame(width: 120, height: 36)
                            .background(profile.isFollowing == true ? ShelfColors.backgroundTertiary : ShelfColors.accent)
                            .foregroundStyle(profile.isFollowing == true ? ShelfColors.textPrimary : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.medium))
                    }
                }

                // Favorite books
                if let favorites = profile.user.favoriteBooks, !favorites.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
                        Text("Favorite Books")
                            .font(ShelfFonts.headlineSans)
                            .padding(.horizontal)

                        // TODO: Fetch book details for favorite UUIDs
                        Text("\(favorites.count) favorites selected")
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textSecondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Status filter
                VStack(alignment: .leading, spacing: ShelfSpacing.md) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ShelfSpacing.sm) {
                            StatusFilterChip(title: "All", isSelected: viewModel.selectedStatus == nil) {
                                Task { await viewModel.filterBooks(by: nil) }
                            }
                            ForEach(ReadingStatus.allCases, id: \.self) { status in
                                StatusFilterChip(
                                    title: status.displayName,
                                    isSelected: viewModel.selectedStatus == status
                                ) {
                                    Task { await viewModel.filterBooks(by: status) }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Books list
                    if viewModel.books.isEmpty {
                        Text("No books yet")
                            .font(ShelfFonts.subheadlineSans)
                            .foregroundStyle(ShelfColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, ShelfSpacing.xl)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.books) { userBook in
                                if let book = userBook.book {
                                    NavigationLink(value: book) {
                                        BookCard(book: book, size: .medium)
                                            .padding(.horizontal)
                                            .padding(.vertical, ShelfSpacing.sm)
                                    }
                                    .buttonStyle(.plain)
                                    ShelfDivider().padding(.horizontal)
                                }
                            }
                        }
                    }
                }

                // Shelves
                if !viewModel.shelves.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.md) {
                        Text("Shelves")
                            .font(ShelfFonts.headlineSans)
                            .padding(.horizontal)

                        ForEach(viewModel.shelves) { shelf in
                            NavigationLink {
                                ShelfDetailView(shelf: shelf, userID: viewModel.userID)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shelf.name)
                                            .font(ShelfFonts.subheadlineBold)
                                        if let count = shelf.booksCount {
                                            Text("\(count) books")
                                                .font(ShelfFonts.caption)
                                                .foregroundStyle(ShelfColors.textSecondary)
                                        }
                                    }
                                    Spacer()
                                    if !shelf.isPublic {
                                        Image(systemName: "lock.fill")
                                            .font(ShelfFonts.caption)
                                            .foregroundStyle(ShelfColors.textSecondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(ShelfFonts.caption)
                                        .foregroundStyle(ShelfColors.textTertiary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, ShelfSpacing.xs)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, ShelfSpacing.xxl)
        }
        .shelfPageBackground()
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }
}

// MARK: - Helpers

struct StatColumn: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(ShelfFonts.dataSmall)
            Text(label)
                .font(ShelfFonts.caption)
                .foregroundStyle(ShelfColors.textSecondary)
        }
    }
}

struct StatusFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ShelfFonts.subheadlineBold)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? ShelfColors.accent : ShelfColors.backgroundTertiary)
                .foregroundStyle(isSelected ? .white : ShelfColors.textPrimary)
                .clipShape(Capsule())
        }
    }
}
