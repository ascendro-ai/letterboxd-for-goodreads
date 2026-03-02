import Foundation

@Observable
final class FeedService {
    static let shared = FeedService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Feed

    func getFeed(cursor: String? = nil, limit: Int = 20) async throws -> PaginatedResponse<FeedItem> {
        var queryItems = [URLQueryItem(name: "limit", value: String(limit))]
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/feed", queryItems: queryItems)
    }

    // MARK: - Notifications

    func getNotifications(cursor: String? = nil) async throws -> PaginatedResponse<AppNotification> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/notifications", queryItems: queryItems)
    }

    func markNotificationsRead(ids: [UUID]) async throws {
        let body = ["ids": ids]
        try await api.request(.post, path: "/notifications/read", body: body)
    }
}
