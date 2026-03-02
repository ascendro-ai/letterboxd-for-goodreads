import XCTest
@testable import Shelf

final class ModelDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Book

    func testDecodeBook() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "The Great Gatsby",
            "original_title": null,
            "description": "A novel about the American Dream.",
            "first_published_year": 1925,
            "authors": [{"id": "660e8400-e29b-41d4-a716-446655440000", "name": "F. Scott Fitzgerald"}],
            "subjects": ["fiction", "classic"],
            "cover_image_url": "https://cdn.shelf.app/covers/abc/detail.webp",
            "average_rating": 4.2,
            "ratings_count": 1523,
            "editions_count": 12,
            "bookshop_url": "https://bookshop.org/great-gatsby"
        }
        """.data(using: .utf8)!

        let book = try decoder.decode(Book.self, from: json)
        XCTAssertEqual(book.title, "The Great Gatsby")
        XCTAssertEqual(book.authors.count, 1)
        XCTAssertEqual(book.authors.first?.name, "F. Scott Fitzgerald")
        XCTAssertEqual(book.firstPublishedYear, 1925)
        XCTAssertEqual(book.averageRating, 4.2)
        XCTAssertEqual(book.ratingsCount, 1523)
        XCTAssertEqual(book.subjects.count, 2)
    }

    func testDecodeBookMinimalFields() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "title": "Minimal Book",
            "authors": [],
            "subjects": [],
            "ratings_count": 0,
            "editions_count": 1
        }
        """.data(using: .utf8)!

        let book = try decoder.decode(Book.self, from: json)
        XCTAssertEqual(book.title, "Minimal Book")
        XCTAssertNil(book.originalTitle)
        XCTAssertNil(book.description)
        XCTAssertNil(book.firstPublishedYear)
        XCTAssertNil(book.coverImageURL)
        XCTAssertNil(book.averageRating)
        XCTAssertNil(book.bookshopURL)
        XCTAssertTrue(book.authors.isEmpty)
    }

    // MARK: - Author

    func testDecodeAuthor() throws {
        let json = """
        {
            "id": "660e8400-e29b-41d4-a716-446655440000",
            "name": "Haruki Murakami",
            "bio": "Japanese writer",
            "photo_url": "https://cdn.shelf.app/authors/photo.webp"
        }
        """.data(using: .utf8)!

        let author = try decoder.decode(Author.self, from: json)
        XCTAssertEqual(author.name, "Haruki Murakami")
        XCTAssertEqual(author.bio, "Japanese writer")
        XCTAssertNotNil(author.photoURL)
    }

    // MARK: - Edition

    func testDecodeEdition() throws {
        let json = """
        {
            "id": "770e8400-e29b-41d4-a716-446655440000",
            "work_id": "550e8400-e29b-41d4-a716-446655440000",
            "isbn_10": "0743273567",
            "isbn_13": "9780743273565",
            "publisher": "Scribner",
            "publish_date": "2004-09-30",
            "page_count": 180,
            "format": "paperback",
            "language": "en"
        }
        """.data(using: .utf8)!

        let edition = try decoder.decode(Edition.self, from: json)
        XCTAssertEqual(edition.isbn13, "9780743273565")
        XCTAssertEqual(edition.publisher, "Scribner")
        XCTAssertEqual(edition.pageCount, 180)
        XCTAssertEqual(edition.format, .paperback)
    }

    // MARK: - Feed Item

    func testDecodeFeedItem() throws {
        let json = """
        {
            "id": "110e8400-e29b-41d4-a716-446655440000",
            "user": {
                "id": "220e8400-e29b-41d4-a716-446655440000",
                "username": "booklover",
                "avatar_url": null
            },
            "activity_type": "finished_book",
            "book": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "The Great Gatsby",
                "authors": [{"id": "660e8400-e29b-41d4-a716-446655440000", "name": "F. Scott Fitzgerald"}],
                "subjects": [],
                "ratings_count": 100,
                "editions_count": 5
            },
            "rating": 4.5,
            "review_text": "Brilliant prose.",
            "has_spoilers": false,
            "created_at": "2024-02-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(FeedItem.self, from: json)
        XCTAssertEqual(item.activityType, .finishedBook)
        XCTAssertEqual(item.user.username, "booklover")
        XCTAssertEqual(item.rating, 4.5)
        XCTAssertEqual(item.reviewText, "Brilliant prose.")
        XCTAssertFalse(item.hasSpoilers)
    }

    func testDecodeFeedItemStartedBook() throws {
        let json = """
        {
            "id": "110e8400-e29b-41d4-a716-446655440000",
            "user": {"id": "220e8400-e29b-41d4-a716-446655440000", "username": "reader"},
            "activity_type": "started_book",
            "book": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "1984",
                "authors": [],
                "subjects": [],
                "ratings_count": 0,
                "editions_count": 1
            },
            "has_spoilers": false,
            "created_at": "2024-03-01T08:00:00Z"
        }
        """.data(using: .utf8)!

        let item = try decoder.decode(FeedItem.self, from: json)
        XCTAssertEqual(item.activityType, .startedBook)
        XCTAssertNil(item.rating)
        XCTAssertNil(item.reviewText)
    }

    // MARK: - Paginated Response

    func testDecodePaginatedResponse() throws {
        let json = """
        {
            "items": [
                {
                    "id": "550e8400-e29b-41d4-a716-446655440000",
                    "title": "Test Book",
                    "authors": [],
                    "subjects": [],
                    "ratings_count": 0,
                    "editions_count": 1
                }
            ],
            "next_cursor": "abc123",
            "has_more": true
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PaginatedResponse<Book>.self, from: json)
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.nextCursor, "abc123")
        XCTAssertTrue(response.hasMore)
    }

    func testDecodePaginatedResponseEmpty() throws {
        let json = """
        {
            "items": [],
            "has_more": false
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(PaginatedResponse<Book>.self, from: json)
        XCTAssertTrue(response.items.isEmpty)
        XCTAssertNil(response.nextCursor)
        XCTAssertFalse(response.hasMore)
    }

    // MARK: - Import Status

    func testDecodeImportStatus() throws {
        let json = """
        {
            "status": "processing",
            "total_books": 847,
            "matched": 812,
            "needs_review": 23,
            "unmatched": 12,
            "progress_percent": 67
        }
        """.data(using: .utf8)!

        let status = try decoder.decode(ImportStatus.self, from: json)
        XCTAssertEqual(status.status, .processing)
        XCTAssertEqual(status.totalBooks, 847)
        XCTAssertEqual(status.matched, 812)
        XCTAssertEqual(status.progressPercent, 67)
    }

    func testDecodeAllImportStates() throws {
        for state in ["pending", "processing", "completed", "failed"] {
            let json = """
            {"status": "\(state)", "total_books": 0, "matched": 0, "needs_review": 0, "unmatched": 0, "progress_percent": 0}
            """.data(using: .utf8)!
            let status = try decoder.decode(ImportStatus.self, from: json)
            XCTAssertEqual(status.status.rawValue, state)
        }
    }

    // MARK: - Reading Status

    func testReadingStatusDisplayNames() {
        XCTAssertEqual(ReadingStatus.reading.displayName, "Reading")
        XCTAssertEqual(ReadingStatus.read.displayName, "Read")
        XCTAssertEqual(ReadingStatus.wantToRead.displayName, "Want to Read")
        XCTAssertEqual(ReadingStatus.didNotFinish.displayName, "Did Not Finish")
    }

    func testReadingStatusRawValues() {
        XCTAssertEqual(ReadingStatus.reading.rawValue, "reading")
        XCTAssertEqual(ReadingStatus.read.rawValue, "read")
        XCTAssertEqual(ReadingStatus.wantToRead.rawValue, "want_to_read")
        XCTAssertEqual(ReadingStatus.didNotFinish.rawValue, "did_not_finish")
    }

    func testReadingStatusIconNames() {
        for status in ReadingStatus.allCases {
            XCTAssertFalse(status.iconName.isEmpty, "\(status) should have an icon")
        }
    }

    // MARK: - UserBook

    func testDecodeUserBook() throws {
        let json = """
        {
            "id": "880e8400-e29b-41d4-a716-446655440000",
            "user_id": "220e8400-e29b-41d4-a716-446655440000",
            "work_id": "550e8400-e29b-41d4-a716-446655440000",
            "status": "read",
            "rating": 4.0,
            "review_text": "Great book!",
            "has_spoilers": true,
            "started_at": "2024-01-01T00:00:00Z",
            "finished_at": "2024-01-15T00:00:00Z",
            "is_imported": false,
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-15T00:00:00Z"
        }
        """.data(using: .utf8)!

        let userBook = try decoder.decode(UserBook.self, from: json)
        XCTAssertEqual(userBook.status, .read)
        XCTAssertEqual(userBook.rating, 4.0)
        XCTAssertTrue(userBook.hasSpoilers)
        XCTAssertFalse(userBook.isImported)
        XCTAssertNotNil(userBook.startedAt)
        XCTAssertNotNil(userBook.finishedAt)
    }

    // MARK: - User & UserProfile

    func testDecodeUser() throws {
        let json = """
        {
            "id": "220e8400-e29b-41d4-a716-446655440000",
            "username": "shelf_reader",
            "display_name": "Shelf Reader",
            "avatar_url": "https://cdn.shelf.app/avatars/abc.webp",
            "bio": "I love books",
            "favorite_books": ["550e8400-e29b-41d4-a716-446655440000"],
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(User.self, from: json)
        XCTAssertEqual(user.username, "shelf_reader")
        XCTAssertEqual(user.displayName, "Shelf Reader")
        XCTAssertEqual(user.favoriteBooks?.count, 1)
    }

    func testDecodeUserProfile() throws {
        let json = """
        {
            "user": {
                "id": "220e8400-e29b-41d4-a716-446655440000",
                "username": "shelf_reader"
            },
            "books_count": 42,
            "followers_count": 100,
            "following_count": 50,
            "is_following": true,
            "is_blocked": false,
            "is_muted": false
        }
        """.data(using: .utf8)!

        let profile = try decoder.decode(UserProfile.self, from: json)
        XCTAssertEqual(profile.booksCount, 42)
        XCTAssertEqual(profile.followersCount, 100)
        XCTAssertEqual(profile.isFollowing, true)
    }

    // MARK: - Shelf

    func testDecodeShelf() throws {
        let json = """
        {
            "id": "990e8400-e29b-41d4-a716-446655440000",
            "user_id": "220e8400-e29b-41d4-a716-446655440000",
            "name": "Favorites",
            "slug": "favorites",
            "description": "My all-time favorites",
            "is_public": true,
            "display_order": 0,
            "books_count": 25,
            "created_at": "2024-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let shelf = try decoder.decode(Shelf.self, from: json)
        XCTAssertEqual(shelf.name, "Favorites")
        XCTAssertEqual(shelf.slug, "favorites")
        XCTAssertTrue(shelf.isPublic)
        XCTAssertEqual(shelf.booksCount, 25)
    }

    // MARK: - Notification

    func testDecodeNotification() throws {
        let json = """
        {
            "id": "aa0e8400-e29b-41d4-a716-446655440000",
            "type": "new_follower",
            "title": "New Follower",
            "body": "shelf_reader started following you",
            "is_read": false,
            "metadata": {
                "user_id": "220e8400-e29b-41d4-a716-446655440000",
                "username": "shelf_reader"
            },
            "created_at": "2024-02-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let notification = try decoder.decode(AppNotification.self, from: json)
        XCTAssertEqual(notification.type, "new_follower")
        XCTAssertFalse(notification.isRead)
        XCTAssertEqual(notification.metadata?.username, "shelf_reader")
    }

    // MARK: - Review

    func testDecodeReview() throws {
        let json = """
        {
            "id": "bb0e8400-e29b-41d4-a716-446655440000",
            "user": {"id": "220e8400-e29b-41d4-a716-446655440000", "username": "reviewer"},
            "rating": 5.0,
            "review_text": "A masterpiece!",
            "has_spoilers": false,
            "created_at": "2024-02-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let review = try decoder.decode(Review.self, from: json)
        XCTAssertEqual(review.rating, 5.0)
        XCTAssertEqual(review.reviewText, "A masterpiece!")
        XCTAssertFalse(review.hasSpoilers)
    }

    // MARK: - TasteMatch

    func testDecodeTasteMatch() throws {
        let json = """
        {
            "user": {"id": "220e8400-e29b-41d4-a716-446655440000", "username": "similar_reader"},
            "match_score": 0.87,
            "overlapping_books_count": 15
        }
        """.data(using: .utf8)!

        let match = try decoder.decode(TasteMatch.self, from: json)
        XCTAssertEqual(match.matchScore, 0.87)
        XCTAssertEqual(match.overlappingBooksCount, 15)
        XCTAssertEqual(match.id, match.user.id)
    }

    // MARK: - Error Response

    func testDecodeAPIError() throws {
        let json = """
        {
            "error": {
                "code": "BOOK_NOT_FOUND",
                "message": "No book found with the given ID."
            }
        }
        """.data(using: .utf8)!

        let errorResponse = try decoder.decode(APIErrorResponse.self, from: json)
        XCTAssertEqual(errorResponse.error.code, "BOOK_NOT_FOUND")
        XCTAssertEqual(errorResponse.error.message, "No book found with the given ID.")
    }

    // MARK: - Request Encoding

    func testEncodeLogBookRequest() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let request = LogBookRequest(
            workID: UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!,
            status: .read,
            rating: 4.5,
            reviewText: "Great book",
            hasSpoilers: false
        )

        let data = try encoder.encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["status"] as? String, "read")
        XCTAssertEqual(dict["rating"] as? Double, 4.5)
        XCTAssertEqual(dict["has_spoilers"] as? Bool, false)
    }

    func testEncodeSignupRequestWithInviteCode() throws {
        let encoder = JSONEncoder()

        let request = SignupRequest(email: "test@test.com", password: "password123", username: "testuser", inviteCode: "ABC123")
        let data = try encoder.encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(dict["invite_code"] as? String, "ABC123")
    }

    func testEncodeSignupRequestWithoutInviteCode() throws {
        let encoder = JSONEncoder()

        let request = SignupRequest(email: "test@test.com", password: "password123", username: "testuser", inviteCode: nil)
        let data = try encoder.encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(dict["invite_code"] as? String)
    }
}

// MARK: - Activity Type Tests

final class ActivityTypeTests: XCTestCase {
    func testActivityTypeDisplayText() {
        XCTAssertEqual(ActivityType.finishedBook.displayText, "finished reading")
        XCTAssertEqual(ActivityType.startedBook.displayText, "started reading")
    }

    func testActivityTypeRawValues() {
        XCTAssertEqual(ActivityType.finishedBook.rawValue, "finished_book")
        XCTAssertEqual(ActivityType.startedBook.rawValue, "started_book")
    }
}

// MARK: - Book Format Tests

final class BookFormatTests: XCTestCase {
    func testAllFormats() {
        let formats = BookFormat.allCases
        XCTAssertEqual(formats.count, 4)
        XCTAssertTrue(formats.contains(.hardcover))
        XCTAssertTrue(formats.contains(.paperback))
        XCTAssertTrue(formats.contains(.ebook))
        XCTAssertTrue(formats.contains(.audiobook))
    }
}

// MARK: - API Error Tests

final class APIErrorTests: XCTestCase {
    func testErrorDescriptions() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(APIError.unauthorized.errorDescription, "Please sign in again.")
        XCTAssertEqual(APIError.forbidden.errorDescription, "You don't have permission to do that.")
        XCTAssertEqual(APIError.notFound.errorDescription, "Not found.")
        XCTAssertEqual(APIError.rateLimited.errorDescription, "Too many requests. Please wait a moment.")
        XCTAssertEqual(APIError.serverError.errorDescription, "Something went wrong. Please try again.")
        XCTAssertEqual(APIError.conflict("Username taken").errorDescription, "Username taken")
        XCTAssertEqual(APIError.validationError("Invalid email").errorDescription, "Invalid email")
        XCTAssertEqual(APIError.apiError(code: "ERR", message: "Something").errorDescription, "Something")
    }
}

// MARK: - Deep Link Router Tests

final class DeepLinkRouterTests: XCTestCase {
    private var router: DeepLinkRouter!

    override func setUp() {
        super.setUp()
        router = DeepLinkRouter.shared
        router.pendingDestination = nil
        router.selectedTab = nil
    }

    func testBookDeepLink() {
        let bookID = UUID()
        let url = URL(string: "shelf://book/\(bookID.uuidString)")!
        router.handle(url: url)

        XCTAssertEqual(router.pendingDestination, .bookDetail(bookID))
        XCTAssertEqual(router.selectedTab, .search)
    }

    func testSearchDeepLink() {
        let url = URL(string: "shelf://search?q=great%20gatsby")!
        router.handle(url: url)

        XCTAssertEqual(router.pendingDestination, .search("great gatsby"))
        XCTAssertEqual(router.selectedTab, .search)
    }

    func testUserDeepLink() {
        let userID = UUID()
        let url = URL(string: "shelf://user/\(userID.uuidString)")!
        router.handle(url: url)

        XCTAssertEqual(router.pendingDestination, .userProfile(userID))
        XCTAssertEqual(router.selectedTab, .search)
    }

    func testNotificationsDeepLink() {
        let url = URL(string: "shelf://notifications")!
        router.handle(url: url)

        XCTAssertNil(router.pendingDestination)
        XCTAssertEqual(router.selectedTab, .notifications)
    }

    func testInvalidScheme() {
        let url = URL(string: "https://shelf.app/book/123")!
        router.handle(url: url)

        XCTAssertNil(router.pendingDestination)
        XCTAssertNil(router.selectedTab)
    }

    func testUnknownRoute() {
        let url = URL(string: "shelf://unknown/path")!
        router.handle(url: url)

        XCTAssertNil(router.pendingDestination)
        XCTAssertNil(router.selectedTab)
    }

    func testInvalidBookUUID() {
        let url = URL(string: "shelf://book/not-a-uuid")!
        router.handle(url: url)

        // Should not set a destination for invalid UUID
        XCTAssertNil(router.pendingDestination)
    }

    func testInvalidUserUUID() {
        let url = URL(string: "shelf://user/not-a-uuid")!
        router.handle(url: url)

        XCTAssertNil(router.pendingDestination)
    }
}

// MARK: - DeepLinkDestination Equatable Tests

final class DeepLinkDestinationTests: XCTestCase {
    func testEquality() {
        let id = UUID()
        XCTAssertEqual(DeepLinkDestination.bookDetail(id), DeepLinkDestination.bookDetail(id))
        XCTAssertEqual(DeepLinkDestination.search("test"), DeepLinkDestination.search("test"))
        XCTAssertEqual(DeepLinkDestination.userProfile(id), DeepLinkDestination.userProfile(id))

        XCTAssertNotEqual(DeepLinkDestination.bookDetail(id), DeepLinkDestination.userProfile(id))
        XCTAssertNotEqual(DeepLinkDestination.search("a"), DeepLinkDestination.search("b"))
    }
}
