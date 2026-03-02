import Foundation
@testable import Shelf

/// Factory methods for creating test fixtures.
/// All IDs are deterministic for reproducible tests.
enum MockData {

    static let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let otherUserID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    static let workID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    static let authorID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    static let userBookID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
    static let shelfID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!

    // MARK: - Factory Methods

    static func makeAuthor(
        id: UUID = authorID,
        name: String = "F. Scott Fitzgerald",
        bio: String? = nil,
        photoURL: String? = nil
    ) -> Author {
        Author(id: id, name: name, bio: bio, photoURL: photoURL)
    }

    static func makeBook(
        id: UUID = workID,
        title: String = "The Great Gatsby",
        authors: [Author]? = nil,
        description: String? = "A novel about the American Dream.",
        firstPublishedYear: Int? = 1925,
        coverImageURL: String? = nil,
        averageRating: Double? = 4.2,
        ratingsCount: Int = 1523,
        editionsCount: Int = 12,
        subjects: [String] = ["fiction", "classics"]
    ) -> Book {
        Book(
            id: id,
            title: title,
            originalTitle: nil,
            description: description,
            firstPublishedYear: firstPublishedYear,
            authors: authors ?? [makeAuthor()],
            subjects: subjects,
            coverImageURL: coverImageURL,
            averageRating: averageRating,
            ratingsCount: ratingsCount,
            editionsCount: editionsCount,
            bookshopURL: nil
        )
    }

    static func makeUser(
        id: UUID = userID,
        username: String = "testuser",
        displayName: String? = "Test User",
        avatarURL: String? = nil,
        bio: String? = "A test user"
    ) -> User {
        User(
            id: id,
            username: username,
            displayName: displayName,
            avatarURL: avatarURL,
            bio: bio,
            favoriteBooks: [],
            createdAt: Date(timeIntervalSince1970: 1735689600) // 2025-01-01
        )
    }

    static func makeUserBook(
        id: UUID = userBookID,
        userID: UUID = userID,
        workID: UUID = workID,
        status: ReadingStatus = .read,
        rating: Double? = 4.5,
        reviewText: String? = "Brilliant prose.",
        hasSpoilers: Bool = false,
        isImported: Bool = false,
        book: Book? = nil
    ) -> UserBook {
        UserBook(
            id: id,
            userID: userID,
            workID: workID,
            status: status,
            rating: rating,
            reviewText: reviewText,
            hasSpoilers: hasSpoilers,
            startedAt: nil,
            finishedAt: Date(),
            isImported: isImported,
            createdAt: Date(),
            updatedAt: Date(),
            book: book
        )
    }

    static func makeShelf(
        id: UUID = shelfID,
        userID: UUID = userID,
        name: String = "Favorites",
        isPublic: Bool = true
    ) -> Shelf {
        Shelf(
            id: id,
            userID: userID,
            name: name,
            slug: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            description: "My favorite books",
            isPublic: isPublic,
            displayOrder: 0,
            booksCount: 5,
            createdAt: Date()
        )
    }

    static func makeReview(
        id: UUID = UUID(),
        user: User? = nil,
        rating: Double = 4.0,
        reviewText: String? = "Great read!",
        hasSpoilers: Bool = false
    ) -> Review {
        Review(
            id: id,
            user: user ?? makeUser(),
            rating: rating,
            reviewText: reviewText,
            hasSpoilers: hasSpoilers,
            createdAt: Date()
        )
    }

    static func makeFeedItem(
        id: UUID = UUID(),
        user: User? = nil,
        activityType: ActivityType = .finishedBook,
        book: Book? = nil,
        rating: Double? = 4.5,
        reviewText: String? = "Brilliant prose.",
        hasSpoilers: Bool = false
    ) -> FeedItem {
        FeedItem(
            id: id,
            user: user ?? makeUser(),
            activityType: activityType,
            book: book ?? makeBook(),
            rating: rating,
            reviewText: reviewText,
            hasSpoilers: hasSpoilers,
            createdAt: Date()
        )
    }

    static func makePaginatedResponse<T: Codable>(
        items: [T],
        hasMore: Bool = false
    ) -> PaginatedResponse<T> {
        PaginatedResponse(
            items: items,
            nextCursor: hasMore ? "eyJjcmVhdGVkX2F0IjoiMjAyNi0wMS0wMSJ9" : nil,
            hasMore: hasMore
        )
    }

    // MARK: - JSON Strings for Codable Tests

    static let bookJSON = """
    {
        "id": "33333333-3333-3333-3333-333333333333",
        "title": "The Great Gatsby",
        "original_title": null,
        "description": "A novel about the American Dream.",
        "first_published_year": 1925,
        "authors": [{"id": "44444444-4444-4444-4444-444444444444", "name": "F. Scott Fitzgerald"}],
        "subjects": ["fiction", "classics"],
        "cover_image_url": null,
        "average_rating": 4.2,
        "ratings_count": 1523,
        "editions_count": 12,
        "bookshop_url": null
    }
    """

    static let userJSON = """
    {
        "id": "11111111-1111-1111-1111-111111111111",
        "username": "testuser",
        "display_name": "Test User",
        "avatar_url": null,
        "bio": "A test user",
        "favorite_books": [],
        "created_at": "2026-01-01T00:00:00Z"
    }
    """

    static let userBookJSON = """
    {
        "id": "55555555-5555-5555-5555-555555555555",
        "user_id": "11111111-1111-1111-1111-111111111111",
        "work_id": "33333333-3333-3333-3333-333333333333",
        "status": "read",
        "rating": 4.5,
        "review_text": "Brilliant prose.",
        "has_spoilers": false,
        "started_at": null,
        "finished_at": "2026-02-15T00:00:00Z",
        "is_imported": false,
        "created_at": "2026-02-15T12:00:00Z",
        "updated_at": "2026-02-15T12:00:00Z"
    }
    """

    static let shelfJSON = """
    {
        "id": "66666666-6666-6666-6666-666666666666",
        "user_id": "11111111-1111-1111-1111-111111111111",
        "name": "Favorites",
        "slug": "favorites",
        "description": "My favorite books",
        "is_public": true,
        "display_order": 0,
        "books_count": 5,
        "created_at": "2026-01-01T00:00:00Z"
    }
    """

    static let feedItemJSON = """
    {
        "id": "77777777-7777-7777-7777-777777777777",
        "user": {
            "id": "11111111-1111-1111-1111-111111111111",
            "username": "testuser",
            "avatar_url": null
        },
        "activity_type": "finished_book",
        "book": {
            "id": "33333333-3333-3333-3333-333333333333",
            "title": "The Great Gatsby",
            "authors": [{"id": "44444444-4444-4444-4444-444444444444", "name": "F. Scott Fitzgerald"}],
            "subjects": ["fiction"],
            "ratings_count": 1523,
            "editions_count": 12
        },
        "rating": 4.5,
        "review_text": "Brilliant prose.",
        "has_spoilers": false,
        "created_at": "2026-02-01T12:00:00Z"
    }
    """
}
