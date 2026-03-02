import XCTest
@testable import Shelf

final class FeedTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testDecodeFeedItem() throws {
        let data = MockData.feedItemJSON.data(using: .utf8)!
        let item = try decoder.decode(FeedItem.self, from: data)

        XCTAssertEqual(item.activityType, .finishedBook)
        XCTAssertEqual(item.user.username, "testuser")
        XCTAssertEqual(item.book.title, "The Great Gatsby")
        XCTAssertEqual(item.rating, 4.5)
        XCTAssertEqual(item.reviewText, "Brilliant prose.")
        XCTAssertFalse(item.hasSpoilers)
    }

    func testDecodeStartedBookActivity() throws {
        let json = """
        {
            "id": "77777777-7777-7777-7777-777777777777",
            "user": {
                "id": "11111111-1111-1111-1111-111111111111",
                "username": "reader"
            },
            "activity_type": "started_book",
            "book": {
                "id": "33333333-3333-3333-3333-333333333333",
                "title": "Dune",
                "authors": [{"id": "44444444-4444-4444-4444-444444444444", "name": "Frank Herbert"}],
                "subjects": ["sci-fi"],
                "ratings_count": 2000,
                "editions_count": 8
            },
            "rating": null,
            "review_text": null,
            "has_spoilers": false,
            "created_at": "2026-02-01T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let item = try decoder.decode(FeedItem.self, from: data)

        XCTAssertEqual(item.activityType, .startedBook)
        XCTAssertNil(item.rating)
        XCTAssertNil(item.reviewText)
    }

    func testActivityTypeDisplayText() {
        XCTAssertFalse(ActivityType.finishedBook.displayText.isEmpty)
        XCTAssertFalse(ActivityType.startedBook.displayText.isEmpty)
    }

    func testDecodeNotification() throws {
        let json = """
        {
            "id": "88888888-8888-8888-8888-888888888888",
            "type": "new_follower",
            "title": "New follower",
            "body": "booklover started following you",
            "is_read": false,
            "metadata": {
                "user_id": "22222222-2222-2222-2222-222222222222",
                "username": "booklover"
            },
            "created_at": "2026-02-01T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let notification = try decoder.decode(AppNotification.self, from: data)

        XCTAssertEqual(notification.type, "new_follower")
        XCTAssertEqual(notification.title, "New follower")
        XCTAssertFalse(notification.isRead)
        XCTAssertEqual(notification.metadata?.username, "booklover")
        XCTAssertEqual(notification.metadata?.userID, MockData.otherUserID)
    }

    func testDecodeNotificationWithBookMetadata() throws {
        let json = """
        {
            "id": "88888888-8888-8888-8888-888888888888",
            "type": "book_recommendation",
            "title": "Book recommendation",
            "body": "You might like this book",
            "is_read": true,
            "metadata": {
                "book_id": "33333333-3333-3333-3333-333333333333",
                "book_title": "The Great Gatsby"
            },
            "created_at": "2026-02-01T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let notification = try decoder.decode(AppNotification.self, from: data)

        XCTAssertTrue(notification.isRead)
        XCTAssertEqual(notification.metadata?.bookID, MockData.workID)
        XCTAssertEqual(notification.metadata?.bookTitle, "The Great Gatsby")
    }

    func testDecodeNotificationWithoutMetadata() throws {
        let json = """
        {
            "id": "88888888-8888-8888-8888-888888888888",
            "type": "system",
            "title": "Welcome",
            "body": "Welcome to Shelf!",
            "is_read": false,
            "metadata": null,
            "created_at": "2026-02-01T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let notification = try decoder.decode(AppNotification.self, from: data)

        XCTAssertNil(notification.metadata)
    }

    func testDecodeTasteMatch() throws {
        let json = """
        {
            "user": {
                "id": "22222222-2222-2222-2222-222222222222",
                "username": "kindred_spirit"
            },
            "match_score": 0.87,
            "overlapping_books_count": 15
        }
        """
        let data = json.data(using: .utf8)!
        let match = try decoder.decode(TasteMatch.self, from: data)

        XCTAssertEqual(match.user.username, "kindred_spirit")
        XCTAssertEqual(match.matchScore, 0.87, accuracy: 0.01)
        XCTAssertEqual(match.overlappingBooksCount, 15)
        XCTAssertEqual(match.id, MockData.otherUserID) // derived from user.id
    }

    func testFeedItemHashable() {
        let item1 = MockData.makeFeedItem()
        let item2 = MockData.makeFeedItem()
        XCTAssertEqual(item1, item2)
    }

    func testDecodePaginatedFeed() throws {
        let json = """
        {
            "items": [
                {
                    "id": "77777777-7777-7777-7777-777777777777",
                    "user": {"id": "11111111-1111-1111-1111-111111111111", "username": "testuser"},
                    "activity_type": "finished_book",
                    "book": {
                        "id": "33333333-3333-3333-3333-333333333333",
                        "title": "Book 1",
                        "authors": [],
                        "subjects": [],
                        "ratings_count": 0,
                        "editions_count": 1
                    },
                    "rating": 4.0,
                    "review_text": null,
                    "has_spoilers": false,
                    "created_at": "2026-02-01T12:00:00Z"
                }
            ],
            "next_cursor": "abc123",
            "has_more": true
        }
        """
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(PaginatedResponse<FeedItem>.self, from: data)

        XCTAssertEqual(response.items.count, 1)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.nextCursor, "abc123")
    }
}
