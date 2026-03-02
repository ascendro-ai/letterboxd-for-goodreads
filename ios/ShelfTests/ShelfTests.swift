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

    // MARK: - Reading Status

    func testReadingStatusDisplayNames() {
        XCTAssertEqual(ReadingStatus.reading.displayName, "Reading")
        XCTAssertEqual(ReadingStatus.read.displayName, "Read")
        XCTAssertEqual(ReadingStatus.wantToRead.displayName, "Want to Read")
        XCTAssertEqual(ReadingStatus.didNotFinish.displayName, "Did Not Finish")
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
}
