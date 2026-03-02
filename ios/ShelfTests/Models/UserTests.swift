import XCTest
@testable import Shelf

final class UserTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testDecodeUserFromJSON() throws {
        let data = MockData.userJSON.data(using: .utf8)!
        let user = try decoder.decode(User.self, from: data)

        XCTAssertEqual(user.id, MockData.userID)
        XCTAssertEqual(user.username, "testuser")
        XCTAssertEqual(user.displayName, "Test User")
        XCTAssertEqual(user.bio, "A test user")
        XCTAssertNil(user.avatarURL)
        XCTAssertEqual(user.favoriteBooks, [])
    }

    func testDecodeUserWithNilOptionals() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "username": "minimal",
            "display_name": null,
            "avatar_url": null,
            "bio": null,
            "favorite_books": null,
            "created_at": null
        }
        """
        let data = json.data(using: .utf8)!
        let user = try decoder.decode(User.self, from: data)

        XCTAssertEqual(user.username, "minimal")
        XCTAssertNil(user.displayName)
        XCTAssertNil(user.avatarURL)
        XCTAssertNil(user.bio)
        XCTAssertNil(user.createdAt)
    }

    func testDecodeUserWithFavoriteBooks() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "username": "bookworm",
            "display_name": "Book Worm",
            "avatar_url": "https://example.com/avatar.jpg",
            "bio": "I love books",
            "favorite_books": [
                "33333333-3333-3333-3333-333333333333",
                "44444444-4444-4444-4444-444444444444"
            ],
            "created_at": "2026-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let user = try decoder.decode(User.self, from: data)

        XCTAssertEqual(user.favoriteBooks?.count, 2)
        XCTAssertEqual(user.avatarURL, "https://example.com/avatar.jpg")
    }

    func testUserHashable() {
        let user1 = MockData.makeUser()
        let user2 = MockData.makeUser()
        let user3 = MockData.makeUser(id: MockData.otherUserID, username: "other")

        XCTAssertEqual(user1, user2)
        XCTAssertNotEqual(user1, user3)
    }

    func testDecodeUserProfile() throws {
        let json = """
        {
            "user": {
                "id": "11111111-1111-1111-1111-111111111111",
                "username": "testuser",
                "display_name": "Test User",
                "avatar_url": null,
                "bio": "A test user",
                "favorite_books": [],
                "created_at": "2026-01-01T00:00:00Z"
            },
            "books_count": 42,
            "followers_count": 100,
            "following_count": 50,
            "is_following": true,
            "is_blocked": false,
            "is_muted": false
        }
        """
        let data = json.data(using: .utf8)!
        let profile = try decoder.decode(UserProfile.self, from: data)

        XCTAssertEqual(profile.user.username, "testuser")
        XCTAssertEqual(profile.booksCount, 42)
        XCTAssertEqual(profile.followersCount, 100)
        XCTAssertEqual(profile.followingCount, 50)
        XCTAssertEqual(profile.isFollowing, true)
        XCTAssertEqual(profile.isBlocked, false)
    }

    func testDecodeUpdateProfileRequest() throws {
        let request = UpdateProfileRequest(
            displayName: "New Name",
            bio: "Updated bio",
            avatarURL: nil,
            favoriteBooks: [MockData.workID]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoded = try decoder.decode(UpdateProfileRequest.self, from: data)
        XCTAssertEqual(decoded.displayName, "New Name")
        XCTAssertEqual(decoded.bio, "Updated bio")
        XCTAssertEqual(decoded.favoriteBooks?.count, 1)
    }
}
