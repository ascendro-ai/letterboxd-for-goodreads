import SwiftUI

struct MyProfileView: View {
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        ProfileContentView(viewModel: viewModel)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
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
            }
        }
        .task {
            if viewModel.profile == nil {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private func profileContent(_ profile: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Avatar + name
                VStack(spacing: 10) {
                    UserAvatarView(url: profile.user.avatarURL, size: 80)

                    VStack(spacing: 4) {
                        if let displayName = profile.user.displayName {
                            Text(displayName)
                                .font(.title3.bold())
                        }
                        Text("@\(profile.user.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let bio = profile.user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }

                // Stats
                HStack(spacing: 32) {
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
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 120, height: 36)
                            .background(profile.isFollowing == true ? Color(.systemGray5) : Color.accentColor)
                            .foregroundStyle(profile.isFollowing == true ? Color.primary : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Favorite books
                if let favorites = profile.user.favoriteBooks, !favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Favorite Books")
                            .font(.headline)
                            .padding(.horizontal)

                        // TODO: Fetch book details for favorite UUIDs
                        Text("\(favorites.count) favorites selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Status filter
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
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
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.books) { userBook in
                                if let book = userBook.book {
                                    NavigationLink(value: book) {
                                        BookCard(book: book, size: .medium)
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                    }
                }

                // Shelves
                if !viewModel.shelves.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Shelves")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.shelves) { shelf in
                            NavigationLink {
                                ShelfDetailView(shelf: shelf, userID: viewModel.userID)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(shelf.name)
                                            .font(.subheadline.weight(.medium))
                                        if let count = shelf.booksCount {
                                            Text("\(count) books")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if !shelf.isPublic {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
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
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
