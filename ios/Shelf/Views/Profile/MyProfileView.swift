import SwiftUI

struct MyProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @Namespace private var coverNamespace

    var body: some View {
        ProfileContentView(viewModel: viewModel, coverNamespace: coverNamespace)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
    }
}

struct UserProfileView: View {
    let userID: UUID
    @State private var viewModel: ProfileViewModel
    @Namespace private var coverNamespace

    init(userID: UUID) {
        self.userID = userID
        self._viewModel = State(initialValue: ProfileViewModel(userID: userID))
    }

    var body: some View {
        ProfileContentView(viewModel: viewModel, coverNamespace: coverNamespace)
    }
}

struct ProfileContentView: View {
    @Bindable var viewModel: ProfileViewModel
    var coverNamespace: Namespace.ID
    @State private var displayMode: ProfileDisplayMode = .grid

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
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        if let displayName = profile.user.displayName {
                            Text(displayName)
                                .font(.title3.bold())
                        }
                        Text("@\(profile.user.username)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

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
                    .accessibilityLabel(profile.isFollowing == true ? "Unfollow \(profile.user.username)" : "Follow \(profile.user.username)")
                }

                // Favorite books
                if let favorites = profile.user.favoriteBooks, !favorites.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Favorite Books")
                            .font(.headline)
                            .padding(.horizontal)

                        Text("\(favorites.count) favorites selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Display mode toggle + status filter
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
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
                            .padding(.leading)
                        }

                        // Grid/List toggle
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                displayMode = displayMode == .grid ? .list : .grid
                            }
                        } label: {
                            Image(systemName: displayMode == .grid ? "list.bullet" : "square.grid.3x3")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(displayMode == .grid ? "Switch to list view" : "Switch to grid view")
                        .padding(.trailing, 8)
                    }

                    // Books display
                    if viewModel.books.isEmpty {
                        Text("No books yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else if displayMode == .grid {
                        coverGrid
                    } else {
                        booksList
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

    // MARK: - Cover Grid

    private var coverGrid: some View {
        let booksWithCovers = viewModel.books.compactMap(\.book)
        return CoverGridView(books: booksWithCovers, columns: 3) { book in
            // Navigation handled via NavigationLink path
        }
        .frame(minHeight: CGFloat(max(1, (booksWithCovers.count + 2) / 3)) * 180)
    }

    // MARK: - Books List

    private var booksList: some View {
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

// MARK: - Display Mode

enum ProfileDisplayMode {
    case grid, list
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
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
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
