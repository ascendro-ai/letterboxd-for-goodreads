/// Contacts sync view accessible from Settings.
/// Requests contacts permission, syncs hashed identifiers, and shows matched users.

import SwiftUI

struct ContactsSyncView: View {
    @State private var matchedUsers: [User] = []
    @State private var followedIDs: Set<UUID> = []
    @State private var isLoading = false
    @State private var permissionDenied = false
    @State private var hasLoaded = false

    private let contactsService = ContactsService.shared
    private let socialService = SocialService.shared

    var body: some View {
        Group {
            if permissionDenied {
                EmptyStateView(
                    icon: "person.crop.rectangle.stack",
                    title: "Contacts Access Required",
                    message: "Open Settings to allow Shelf to find friends from your contacts."
                )
            } else if isLoading {
                LoadingStateView(message: "Finding friends...")
            } else if hasLoaded && matchedUsers.isEmpty {
                EmptyStateView(
                    icon: "person.2",
                    title: "No matches found",
                    message: "None of your contacts are on Shelf yet. Invite friends to join!"
                )
            } else if !matchedUsers.isEmpty {
                List {
                    ForEach(matchedUsers) { user in
                        NavigationLink {
                            UserProfileView(userID: user.id)
                        } label: {
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

                                Button {
                                    toggleFollow(user)
                                } label: {
                                    Text(followedIDs.contains(user.id) ? "Following" : "Follow")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(followedIDs.contains(user.id) ? Color(.systemGray5) : Color.accentColor)
                                        .foregroundStyle(followedIDs.contains(user.id) ? Color.primary : Color.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Find Friends")
        .task {
            await syncIfNeeded()
        }
    }

    private func syncIfNeeded() async {
        guard !hasLoaded else { return }
        isLoading = true

        let granted = await contactsService.requestAccess()
        if !granted {
            permissionDenied = true
            isLoading = false
            hasLoaded = true
            return
        }

        do {
            matchedUsers = try await contactsService.syncContacts()
        } catch {
            // Sync failed — show empty state
        }

        isLoading = false
        hasLoaded = true
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
