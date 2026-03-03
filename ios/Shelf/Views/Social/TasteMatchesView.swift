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
        .shelfPageBackground()
    }

    private var matchesList: some View {
        List {
            ForEach(matches, id: \.user.id) { match in
                NavigationLink {
                    UserProfileView(userID: match.user.id)
                } label: {
                    HStack(spacing: ShelfSpacing.md) {
                        UserAvatarView(url: match.user.avatarURL, size: 44)

                        VStack(alignment: .leading, spacing: ShelfSpacing.xxs) {
                            Text(match.user.username)
                                .font(ShelfFonts.subheadlineBold)
                                .foregroundStyle(ShelfColors.textPrimary)

                            Text("\(match.overlappingBooksCount) books in common")
                                .font(ShelfFonts.caption)
                                .foregroundStyle(ShelfColors.textSecondary)
                        }

                        Spacer()

                        Text("\(Int(match.matchScore * 100))%")
                            .font(ShelfFonts.dataMedium)
                            .foregroundStyle(ShelfColors.accent)
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
            matches = try await socialService.getTasteMatches()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
