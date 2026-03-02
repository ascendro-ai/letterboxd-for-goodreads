import Foundation

@Observable
final class NotificationsViewModel {
    private(set) var notifications: [AppNotification] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    private var nextCursor: String?
    private var hasMore = true

    private let feedService = FeedService.shared

    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    @MainActor
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let response = try await feedService.getNotifications()
            notifications = response.items
            nextCursor = response.nextCursor
            hasMore = response.hasMore
        } catch {
            self.error = error
        }

        isLoading = false
    }

    @MainActor
    func markAllRead() async {
        let unreadIDs = notifications.filter { !$0.isRead }.map(\.id)
        guard !unreadIDs.isEmpty else { return }

        try? await feedService.markNotificationsRead(ids: unreadIDs)
        await load()
    }

    @MainActor
    func refresh() async {
        nextCursor = nil
        hasMore = true
        await load()
    }
}
