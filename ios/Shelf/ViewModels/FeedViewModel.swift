import Foundation

@Observable
final class FeedViewModel {
    private(set) var items: [FeedItem] = []
    private(set) var feedType: FeedType = .following
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var error: Error?
    private var nextCursor: String?
    private var hasMore = true

    private let feedService = FeedService.shared

    var isPopularOrMixed: Bool {
        feedType == .popular || feedType == .mixed
    }

    @MainActor
    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response = try await feedService.getFeed()
            items = response.items
            feedType = response.feedType
            nextCursor = response.nextCursor
            hasMore = response.hasMore
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
}
