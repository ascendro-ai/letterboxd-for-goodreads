import XCTest
@testable import Shelf

final class UserBookTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testDecodeUserBook() throws {
        let data = MockData.userBookJSON.data(using: .utf8)!
        let userBook = try decoder.decode(UserBook.self, from: data)

        XCTAssertEqual(userBook.id, MockData.userBookID)
        XCTAssertEqual(userBook.userID, MockData.userID)
        XCTAssertEqual(userBook.workID, MockData.workID)
        XCTAssertEqual(userBook.status, .read)
        XCTAssertEqual(userBook.rating, 4.5, accuracy: 0.01)
        XCTAssertEqual(userBook.reviewText, "Brilliant prose.")
        XCTAssertFalse(userBook.hasSpoilers)
        XCTAssertFalse(userBook.isImported)
        XCTAssertNil(userBook.startedAt)
        XCTAssertNotNil(userBook.finishedAt)
    }

    func testHalfStarRatings() throws {
        let ratings: [Double] = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]
        for rating in ratings {
            let json = """
            {
                "id": "55555555-5555-5555-5555-555555555555",
                "user_id": "11111111-1111-1111-1111-111111111111",
                "work_id": "33333333-3333-3333-3333-333333333333",
                "status": "read",
                "rating": \(rating),
                "review_text": null,
                "has_spoilers": false,
                "started_at": null,
                "finished_at": null,
                "is_imported": false,
                "created_at": "2026-01-01T00:00:00Z",
                "updated_at": "2026-01-01T00:00:00Z"
            }
            """
            let data = json.data(using: .utf8)!
            let userBook = try decoder.decode(UserBook.self, from: data)
            XCTAssertEqual(userBook.rating, rating, accuracy: 0.01,
                           "Rating \(rating) should decode correctly")
        }
    }

    func testDecodeUserBookWithNullRating() throws {
        let json = """
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "user_id": "11111111-1111-1111-1111-111111111111",
            "work_id": "33333333-3333-3333-3333-333333333333",
            "status": "want_to_read",
            "rating": null,
            "review_text": null,
            "has_spoilers": false,
            "started_at": null,
            "finished_at": null,
            "is_imported": false,
            "created_at": "2026-01-01T00:00:00Z",
            "updated_at": "2026-01-01T00:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let userBook = try decoder.decode(UserBook.self, from: data)

        XCTAssertEqual(userBook.status, .wantToRead)
        XCTAssertNil(userBook.rating)
        XCTAssertNil(userBook.reviewText)
    }

    func testDecodeUserBookWithEmbeddedBook() throws {
        let json = """
        {
            "id": "55555555-5555-5555-5555-555555555555",
            "user_id": "11111111-1111-1111-1111-111111111111",
            "work_id": "33333333-3333-3333-3333-333333333333",
            "status": "reading",
            "rating": null,
            "review_text": null,
            "has_spoilers": false,
            "started_at": "2026-02-01T00:00:00Z",
            "finished_at": null,
            "is_imported": false,
            "created_at": "2026-02-01T00:00:00Z",
            "updated_at": "2026-02-01T00:00:00Z",
            "book": {
                "id": "33333333-3333-3333-3333-333333333333",
                "title": "The Great Gatsby",
                "authors": [{"id": "44444444-4444-4444-4444-444444444444", "name": "F. Scott Fitzgerald"}],
                "subjects": ["fiction"],
                "ratings_count": 1523,
                "editions_count": 12
            }
        }
        """
        let data = json.data(using: .utf8)!
        let userBook = try decoder.decode(UserBook.self, from: data)

        XCTAssertEqual(userBook.status, .reading)
        XCTAssertNotNil(userBook.startedAt)
        XCTAssertNotNil(userBook.book)
        XCTAssertEqual(userBook.book?.title, "The Great Gatsby")
    }

    func testReadingStatusDisplayNames() {
        XCTAssertEqual(ReadingStatus.reading.displayName, "Reading")
        XCTAssertEqual(ReadingStatus.read.displayName, "Read")
        XCTAssertEqual(ReadingStatus.wantToRead.displayName, "Want to Read")
        XCTAssertEqual(ReadingStatus.didNotFinish.displayName, "Did Not Finish")
    }

    func testReadingStatusIconNames() {
        // Each status should have an SF Symbol icon
        for status in ReadingStatus.allCases {
            XCTAssertFalse(status.iconName.isEmpty,
                           "\(status) should have an icon name")
        }
    }

    func testReadingStatusRawValues() {
        XCTAssertEqual(ReadingStatus.reading.rawValue, "reading")
        XCTAssertEqual(ReadingStatus.read.rawValue, "read")
        XCTAssertEqual(ReadingStatus.wantToRead.rawValue, "want_to_read")
        XCTAssertEqual(ReadingStatus.didNotFinish.rawValue, "did_not_finish")
    }

    func testLogBookRequestEncoding() throws {
        let request = LogBookRequest(
            workID: MockData.workID,
            status: .read,
            rating: 4.0,
            reviewText: "Great book!",
            hasSpoilers: false,
            startedAt: nil,
            finishedAt: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["status"] as? String, "read")
        XCTAssertEqual(json["rating"] as? Double, 4.0)
        XCTAssertEqual(json["review_text"] as? String, "Great book!")
    }

    func testUpdateBookRequestEncoding() throws {
        let request = UpdateBookRequest(
            status: .read,
            rating: 5.0,
            reviewText: "Updated review",
            hasSpoilers: true,
            startedAt: nil,
            finishedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["rating"] as? Double, 5.0)
        XCTAssertEqual(json["has_spoilers"] as? Bool, true)
    }
}
