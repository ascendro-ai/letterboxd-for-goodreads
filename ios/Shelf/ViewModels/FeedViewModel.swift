import Foundation

@Observable
final class FeedViewModel {
    private(set) var items: [FeedItem] = []
    private(set) var popularBooks: [Book] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: Error?
    private(set) var showingPopular = false
    private var nextCursor: String?
    private var hasMore = true

    private let feedService = FeedService.shared
    private let bookService = BookService.shared

    @MainActor
    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response = try await feedService.getFeed()
            items = response.items
            nextCursor = response.nextCursor
            hasMore = response.hasMore

            // Cold start: if feed is empty, show popular books
            if items.isEmpty {
                await loadPopular()
            } else {
                showingPopular = false
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    @MainActor
    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor = nextCursor else { return }
        isLoadingMore = true

        do {
            let response = try await feedService.getFeed(cursor: cursor)
            items.append(contentsOf: response.items)
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            // Silently fail for pagination
        }

        isLoadingMore = false
    }

    @MainActor
    func refresh() async {
        nextCursor = nil
        hasMore = true
        await loadFeed()
    }

    @MainActor
    private func loadPopular() async {
        do {
            popularBooks = try await bookService.getPopular()
            showingPopular = true
        } catch {
            // No popular books available — keep empty state
        }
    }
}
