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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        user = try container.decode(User.self, forKey: .user)
        activityType = try container.decode(ActivityType.self, forKey: .activityType)
        book = try container.decode(Book.self, forKey: .book)
        reviewText = try container.decodeIfPresent(String.self, forKey: .reviewText)
        hasSpoilers = try container.decodeIfPresent(Bool.self, forKey: .hasSpoilers) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        // Backend returns rating as string "4.0" — parse flexibly
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .rating) {
            rating = doubleVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .rating) {
            rating = Double(strVal)
        } else {
            rating = nil
        }
    }
}

// MARK: - Notification

struct NotificationActor: Codable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

struct AppNotification: Codable, Identifiable, Hashable {
    let id: UUID
    let type: String
    let actor: NotificationActor?
    let data: NotificationData?
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, type, actor, data
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    var title: String {
        let name = actor?.displayName ?? actor?.username ?? "Someone"
        switch type {
        case "new_follower": return "\(name) followed you"
        case "new_review": return "\(name) reviewed a book"
        case "book_recommendation": return "\(name) recommended a book"
        default: return "New notification"
        }
    }

    var body: String {
        switch type {
        case "new_follower":
            return "@\(actor?.username ?? "unknown") started following you"
        case "new_review":
            let bookTitle = data?.bookTitle ?? "a book"
            return "\(actor?.displayName ?? "Someone") reviewed \(bookTitle)"
        case "book_recommendation":
            let bookTitle = data?.bookTitle ?? "a book"
            return "\(actor?.displayName ?? "Someone") thinks you'd like \(bookTitle)"
        default:
            return ""
        }
    }
}

struct NotificationData: Codable, Hashable {
    let bookID: UUID?
    let bookTitle: String?
    let reviewID: UUID?

    enum CodingKeys: String, CodingKey {
        case bookID = "book_id"
        case bookTitle = "book_title"
        case reviewID = "review_id"
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decode(User.self, forKey: .user)
        overlappingBooksCount = try container.decode(Int.self, forKey: .overlappingBooksCount)
        // Backend returns Decimal as string "0.850" — parse flexibly
        if let doubleVal = try? container.decode(Double.self, forKey: .matchScore) {
            matchScore = doubleVal
        } else if let strVal = try? container.decode(String.self, forKey: .matchScore),
                  let parsed = Double(strVal) {
            matchScore = parsed
        } else {
            matchScore = 0
        }
    }
}
