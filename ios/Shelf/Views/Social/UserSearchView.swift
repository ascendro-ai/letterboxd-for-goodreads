/// Dedicated user search view with debounced input, user results,
/// and inline follow/unfollow buttons.

import SwiftUI

struct UserSearchView: View {
    @State private var query = ""
    @State private var results: [User] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var followedIDs: Set<UUID> = []
    @State private var searchTask: Task<Void, Never>?

    private let socialService = SocialService.shared

    var body: some View {
        List {
            if isSearching && results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if hasSearched && results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(results) { user in
                    NavigationLink {
                        UserProfileView(userID: user.id)
                    } label: {
                        UserSearchRow(
                            user: user,
                            isFollowed: followedIDs.contains(user.id),
                            onToggleFollow: { toggleFollow(user) }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .searchable(text: $query, prompt: "Search by username or name...")
        .onChange(of: query) {
            performSearch()
        }
        .navigationTitle("Find People")
    }

    private func performSearch() {
        searchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            hasSearched = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                let response = try await socialService.searchUsers(query: query)
                guard !Task.isCancelled else { return }
                results = response.items
            } catch {
                guard !Task.isCancelled else { return }
                results = []
            }
            hasSearched = true
            isSearching = false
        }
    }

    private func toggleFollow(_ user: User) {
        Task {
            if followedIDs.contains(user.id) {
                try? await socialService.unfollow(userID: user.id)
                followedIDs.remove(user.id)
            } else {
                try? await socialService.follow(userID: user.id)
                followedIDs.insert(user.id)
            }
        }
    }
}

// MARK: - User Search Row

private struct UserSearchRow: View {
    let user: User
    let isFollowed: Bool
    let onToggleFollow: () -> Void

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

            Button(action: onToggleFollow) {
                Text(isFollowed ? "Following" : "Follow")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isFollowed ? Color(.systemGray5) : Color.accentColor)
                    .foregroundStyle(isFollowed ? Color.primary : Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.username). \(isFollowed ? "Following" : "Not following")")
        .accessibilityHint(isFollowed ? "Double tap to unfollow" : "Double tap to follow")
    }
}
