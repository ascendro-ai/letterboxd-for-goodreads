import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    private let adService = AdService.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                LoadingStateView()
            } else if let error = viewModel.error, viewModel.items.isEmpty {
                ErrorStateView(error: error) {
                    Task { await viewModel.refresh() }
                }
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "newspaper",
                    title: "Your feed is empty",
                    message: "Follow readers to see what they're reading. Or search for books to get started."
                )
            } else {
                feedList
            }
        }
        .shelfPageBackground()
        .navigationTitle("Feed")
        .task {
            if viewModel.items.isEmpty {
                await viewModel.loadFeed()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.items.count) {
            adService.recalculateSpacing()
        }
    }

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Cold start: show header + discover prompt for popular/mixed feeds
                if viewModel.isPopularOrMixed {
                    VStack(spacing: ShelfSpacing.md) {
                        Text("Popular This Week")
                            .font(ShelfFonts.headlineSerif)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, ShelfSpacing.sm)
                            .accessibilityAddTraits(.isHeader)

                        DiscoverPromptCard()
                    }

                    ShelfDivider()
                        .padding(.horizontal)
                        .padding(.top, ShelfSpacing.sm)
                }

                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item.book) {
                        FeedItemView(item: item)
                    }
                    .buttonStyle(.plain)

                    ShelfDivider()
                        .padding(.horizontal)

                    // Insert native ad card at randomized intervals
                    if adService.shouldInsertAd(at: index) {
                        NativeAdCardView()
                        ShelfDivider()
                            .padding(.horizontal)
                    }

                    // Load more when nearing end
                    if index == viewModel.items.count - 3 {
                        Color.clear
                            .frame(height: 1)
                            .task {
                                await viewModel.loadMore()
                            }
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(ShelfColors.accent)
                        .padding()
                }
            }
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }
}
