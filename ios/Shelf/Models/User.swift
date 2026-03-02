import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: String?
    let bio: String?
    let favoriteBooks: [UUID]?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case favoriteBooks = "favorite_books"
        case createdAt = "created_at"
    }
}

struct UserProfile: Codable {
    let user: User
    let booksCount: Int
    let followersCount: Int
    let followingCount: Int
    let isFollowing: Bool?
    let isBlocked: Bool?
    let isMuted: Bool?

    enum CodingKeys: String, CodingKey {
        case user
        case booksCount = "books_count"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case isFollowing = "is_following"
        case isBlocked = "is_blocked"
        case isMuted = "is_muted"
    }
}

struct UpdateProfileRequest: Codable {
    var displayName: String?
    var bio: String?
    var avatarURL: String?
    var favoriteBooks: [UUID]?

    enum CodingKeys: String, CodingKey {
        case bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case favoriteBooks = "favorite_books"
    }
}
