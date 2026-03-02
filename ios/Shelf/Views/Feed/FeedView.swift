import SwiftUI

struct FeedView: View {
    @State private var viewModel = FeedViewModel()
    private let adService = AdService.shared

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty && viewModel.popularBooks.isEmpty {
                LoadingStateView()
            } else if let error = viewModel.error, viewModel.items.isEmpty, viewModel.popularBooks.isEmpty {
                ErrorStateView(error: error) {
                    Task { await viewModel.refresh() }
                }
            } else if viewModel.showingPopular {
                popularFeed
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
        .navigationTitle("Feed")
        .task {
            if viewModel.items.isEmpty {
                await viewModel.loadFeed()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Popular Books (Cold Start)

    private var popularFeed: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Popular This Week")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Text("Follow readers to build your personal feed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                ForEach(viewModel.popularBooks) { book in
                    NavigationLink(value: book) {
                        BookCard(book: book, size: .large)
                            .padding(.horizontal)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.horizontal)
                }
            }
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }

    // MARK: - Activity Feed

    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink(value: item.book) {
                        FeedItemView(item: item)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.horizontal)

                    // Insert native ad card every N items
                    if adService.shouldInsertAd(at: index) {
                        NativeAdCardView()
                        Divider()
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
                        .padding()
                }
            }
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }
}
