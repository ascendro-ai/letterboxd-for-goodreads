import SwiftUI

enum FollowListType {
    case followers
    case following

    var title: String {
        switch self {
        case .followers: "Followers"
        case .following: "Following"
        }
    }
}

struct FollowListView: View {
    let userID: UUID
    let listType: FollowListType

    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var error: Error?

    private let socialService = SocialService.shared

    var body: some View {
        Group {
            if isLoading && users.isEmpty {
                LoadingStateView()
            } else if let error, users.isEmpty {
                ErrorStateView(error: error) {
                    Task { await load() }
                }
            } else if users.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No \(listType.title.lowercased()) yet",
                    message: listType == .followers
                        ? "When people follow this user, they'll appear here."
                        : "This user isn't following anyone yet."
                )
            } else {
                usersList
            }
        }
        .navigationTitle(listType.title)
        .task { await load() }
        .shelfPageBackground()
    }

    private var usersList: some View {
        List(users) { user in
            NavigationLink {
                UserProfileView(userID: user.id)
            } label: {
                HStack(spacing: ShelfSpacing.md) {
                    UserAvatarView(url: user.avatarURL, size: 40)
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
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(ShelfColors.background)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response: PaginatedResponse<User>
            switch listType {
            case .followers:
                response = try await socialService.getFollowers(userID: userID)
            case .following:
                response = try await socialService.getFollowing(userID: userID)
            }
            users = response.items
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
