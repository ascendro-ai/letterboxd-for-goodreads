import SwiftUI

struct TasteMatchesView: View {
    @State private var matches: [TasteMatch] = []
    @State private var isLoading = false
    @State private var error: Error?

    private let socialService = SocialService.shared

    var body: some View {
        Group {
            if isLoading && matches.isEmpty {
                LoadingStateView()
            } else if let error, matches.isEmpty {
                ErrorStateView(error: error) {
                    Task { await load() }
                }
            } else if matches.isEmpty {
                EmptyStateView(
                    icon: "heart.text.square",
                    title: "No taste matches yet",
                    message: "Rate more books to discover readers with similar taste. You need at least 5 shared books."
                )
            } else {
                matchesList
            }
        }
        .navigationTitle("Taste Matches")
        .task { await load() }
    }

    private var matchesList: some View {
        List {
            ForEach(matches, id: \.user.id) { match in
                NavigationLink {
                    UserProfileView(userID: match.user.id)
                } label: {
                    HStack(spacing: 12) {
                        UserAvatarView(url: match.user.avatarURL, size: 44)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.user.username)
                                .font(.subheadline.weight(.semibold))

                            Text("\(match.overlappingBooksCount) books in common")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(Int(match.matchScore * 100))%")
                            .font(.title3.bold())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            matches = try await socialService.getTasteMatches()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
