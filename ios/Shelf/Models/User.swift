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

    init(id: UUID, username: String, displayName: String? = nil, avatarURL: String? = nil,
         bio: String? = nil, favoriteBooks: [UUID]? = nil, createdAt: Date? = nil) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.favoriteBooks = favoriteBooks
        self.createdAt = createdAt
    }
}

struct UserProfile: Decodable {
    let user: User
    let booksCount: Int
    let followersCount: Int
    let followingCount: Int
    let isFollowing: Bool?
    let isBlocked: Bool?
    let isMuted: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, username, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case favoriteBooks = "favorite_books"
        case createdAt = "created_at"
        case booksCount = "books_count"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case isFollowing = "is_following"
        case isBlocked = "is_blocked"
        case isMuted = "is_muted"
    }

    /// Backend returns a flat JSON with user fields + counts at the same level.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = User(
            id: try container.decode(UUID.self, forKey: .id),
            username: try container.decode(String.self, forKey: .username),
            displayName: try container.decodeIfPresent(String.self, forKey: .displayName),
            avatarURL: try container.decodeIfPresent(String.self, forKey: .avatarURL),
            bio: try container.decodeIfPresent(String.self, forKey: .bio),
            favoriteBooks: try container.decodeIfPresent([UUID].self, forKey: .favoriteBooks),
            createdAt: try container.decodeIfPresent(Date.self, forKey: .createdAt)
        )
        booksCount = try container.decodeIfPresent(Int.self, forKey: .booksCount) ?? 0
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        isFollowing = try container.decodeIfPresent(Bool.self, forKey: .isFollowing)
        isBlocked = try container.decodeIfPresent(Bool.self, forKey: .isBlocked)
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted)
    }

    init(user: User, booksCount: Int, followersCount: Int, followingCount: Int,
         isFollowing: Bool?, isBlocked: Bool?, isMuted: Bool?) {
        self.user = user
        self.booksCount = booksCount
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.isFollowing = isFollowing
        self.isBlocked = isBlocked
        self.isMuted = isMuted
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
