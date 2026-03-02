import Foundation

// MARK: - Paginated Response

struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let nextCursor: String?
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

// MARK: - API Error

struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable {
    let code: String
    let message: String
}

// MARK: - Auth

struct SignupRequest: Codable {
    let email: String
    let password: String
    let username: String
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct OAuthRequest: Codable {
    let idToken: String
    let username: String?

    enum CodingKeys: String, CodingKey {
        case username
        case idToken = "id_token"
    }
}

struct RefreshRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

// MARK: - Import

enum ImportSource: String, Codable {
    case goodreads
    case storygraph
    case kindle
    case kobo
}

struct ImportStatus: Codable {
    let status: ImportState
    let totalBooks: Int
    let matched: Int
    let needsReview: Int
    let unmatched: Int
    let progressPercent: Int

    enum CodingKeys: String, CodingKey {
        case status
        case totalBooks = "total_books"
        case matched
        case needsReview = "needs_review"
        case unmatched
        case progressPercent = "progress_percent"
    }
}

enum ImportState: String, Codable {
    case pending
    case processing
    case completed
    case failed
}

// MARK: - Review

struct Review: Codable, Identifiable, Hashable {
    let id: UUID
    let user: User
    let rating: Double
    let reviewText: String?
    let hasSpoilers: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, user, rating
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case createdAt = "created_at"
    }
}
