import Foundation

@Observable
final class SocialService {
    static let shared = SocialService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Follow

    func follow(userID: UUID) async throws {
        try await api.request(.post, path: "/users/\(userID.uuidString)/follow")
    }

    func unfollow(userID: UUID) async throws {
        try await api.request(.delete, path: "/users/\(userID.uuidString)/follow")
    }

    func getFollowers(userID: UUID, cursor: String? = nil) async throws -> PaginatedResponse<User> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/users/\(userID.uuidString)/followers", queryItems: queryItems)
    }

    func getFollowing(userID: UUID, cursor: String? = nil) async throws -> PaginatedResponse<User> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/users/\(userID.uuidString)/following", queryItems: queryItems)
    }

    // MARK: - Block

    func block(userID: UUID) async throws {
        try await api.request(.post, path: "/users/\(userID.uuidString)/block")
    }

    func unblock(userID: UUID) async throws {
        try await api.request(.delete, path: "/users/\(userID.uuidString)/block")
    }

    // MARK: - Mute

    func mute(userID: UUID) async throws {
        try await api.request(.post, path: "/users/\(userID.uuidString)/mute")
    }

    func unmute(userID: UUID) async throws {
        try await api.request(.delete, path: "/users/\(userID.uuidString)/mute")
    }

    // MARK: - Taste Matches

    func getTasteMatches() async throws -> [TasteMatch] {
        try await api.request(.get, path: "/me/taste-matches")
    }

    // MARK: - User Search

    func searchUsers(query: String) async throws -> PaginatedResponse<User> {
        let queryItems = [URLQueryItem(name: "q", value: query)]
        return try await api.request(.get, path: "/users/search", queryItems: queryItems)
    }

    // MARK: - User Profile

    func getProfile(userID: UUID) async throws -> UserProfile {
        try await api.request(.get, path: "/users/\(userID.uuidString)")
    }

    func getMyProfile() async throws -> User {
        try await api.request(.get, path: "/me")
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws -> User {
        try await api.request(.patch, path: "/me", body: request)
    }
}
