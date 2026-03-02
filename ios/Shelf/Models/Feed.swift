import Foundation

// MARK: - Feed Type

enum FeedType: String, Codable {
    case following
    case popular
    case mixed
}

// MARK: - Feed Response

struct FeedResponse: Codable {
    let feedType: FeedType
    let items: [FeedItem]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case feedType = "feed_type"
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

// MARK: - Activity Type

enum ActivityType: String, Codable {
    case finishedBook = "finished_book"
    case startedBook = "started_book"

    var displayText: String {
        switch self {
        case .finishedBook: "finished reading"
        case .startedBook: "started reading"
        }
    }
}

// MARK: - Feed Item

struct FeedItem: Codable, Identifiable, Hashable {
    let id: UUID
    let user: User
    let activityType: ActivityType
    let book: Book
    let rating: Double?
    let reviewText: String?
    let hasSpoilers: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, user, book, rating
        case activityType = "activity_type"
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case createdAt = "created_at"
    }
}

// MARK: - Notification

struct AppNotification: Codable, Identifiable, Hashable {
    let id: UUID
    let type: String
    let title: String
    let body: String
    let isRead: Bool
    let metadata: NotificationMetadata?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, metadata
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

struct NotificationMetadata: Codable, Hashable {
    let userID: UUID?
    let bookID: UUID?
    let username: String?
    let bookTitle: String?

    enum CodingKeys: String, CodingKey {
        case username
        case userID = "user_id"
        case bookID = "book_id"
        case bookTitle = "book_title"
    }
}

// MARK: - Taste Match

struct TasteMatch: Codable, Identifiable, Hashable {
    var id: UUID { user.id }
    let user: User
    let matchScore: Double
    let overlappingBooksCount: Int

    enum CodingKeys: String, CodingKey {
        case user
        case matchScore = "match_score"
        case overlappingBooksCount = "overlapping_books_count"
    }
}
