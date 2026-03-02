import XCTest
@testable import Shelf

final class APIModelTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - APIErrorResponse

    func testDecodeAPIError() throws {
        let json = """
        {
            "error": {
                "code": "BOOK_NOT_FOUND",
                "message": "No book found with the given ID."
            }
        }
        """
        let data = json.data(using: .utf8)!
        let errorResponse = try decoder.decode(APIErrorResponse.self, from: data)

        XCTAssertEqual(errorResponse.error.code, "BOOK_NOT_FOUND")
        XCTAssertEqual(errorResponse.error.message, "No book found with the given ID.")
    }

    func testDecodeAPIErrorVariants() throws {
        let codes = [
            "REVIEW_FLAGGED",
            "DUPLICATE_FLAG",
            "CANNOT_FLAG_OWN_REVIEW",
            "USER_NOT_FOUND",
            "SHELF_LIMIT_REACHED",
        ]

        for code in codes {
            let json = """
            {"error": {"code": "\(code)", "message": "Error message"}}
            """
            let data = json.data(using: .utf8)!
            let errorResponse = try decoder.decode(APIErrorResponse.self, from: data)
            XCTAssertEqual(errorResponse.error.code, code)
        }
    }

    // MARK: - ImportStatus

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
        """
        let data = json.data(using: .utf8)!
        let status = try decoder.decode(ImportStatus.self, from: data)

        XCTAssertEqual(status.status, .processing)
        XCTAssertEqual(status.totalBooks, 847)
        XCTAssertEqual(status.matched, 812)
        XCTAssertEqual(status.needsReview, 23)
        XCTAssertEqual(status.unmatched, 12)
        XCTAssertEqual(status.progressPercent, 67)
    }

    func testImportStateValues() {
        XCTAssertEqual(ImportState.pending.rawValue, "pending")
        XCTAssertEqual(ImportState.processing.rawValue, "processing")
        XCTAssertEqual(ImportState.completed.rawValue, "completed")
        XCTAssertEqual(ImportState.failed.rawValue, "failed")
    }

    func testDecodeCompletedImport() throws {
        let json = """
        {
            "status": "completed",
            "total_books": 100,
            "matched": 95,
            "needs_review": 3,
            "unmatched": 2,
            "progress_percent": 100
        }
        """
        let data = json.data(using: .utf8)!
        let status = try decoder.decode(ImportStatus.self, from: data)

        XCTAssertEqual(status.status, .completed)
        XCTAssertEqual(status.progressPercent, 100)
    }

    // MARK: - PaginatedResponse

    func testDecodePaginatedBooks() throws {
        let json = """
        {
            "items": [
                {
                    "id": "33333333-3333-3333-3333-333333333333",
                    "title": "Book 1",
                    "authors": [{"id": "44444444-4444-4444-4444-444444444444", "name": "Author"}],
                    "subjects": [],
                    "ratings_count": 0,
                    "editions_count": 1
                }
            ],
            "next_cursor": "eyJjcmVhdGVkX2F0IjoiMjAyNi0wMS0wMSJ9",
            "has_more": true
        }
        """
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(PaginatedResponse<Book>.self, from: data)

        XCTAssertEqual(response.items.count, 1)
        XCTAssertTrue(response.hasMore)
        XCTAssertNotNil(response.nextCursor)
    }

    func testDecodePaginatedEmptyResponse() throws {
        let json = """
        {
            "items": [],
            "next_cursor": null,
            "has_more": false
        }
        """
        let data = json.data(using: .utf8)!
        let response = try decoder.decode(PaginatedResponse<Book>.self, from: data)

        XCTAssertTrue(response.items.isEmpty)
        XCTAssertFalse(response.hasMore)
        XCTAssertNil(response.nextCursor)
    }

    // MARK: - Auth Models

    func testDecodeAuthResponse() throws {
        let json = """
        {
            "access_token": "eyJhbGciOiJIUzI1NiJ9.test.payload",
            "refresh_token": "refresh-token-value",
            "user": {
                "id": "11111111-1111-1111-1111-111111111111",
                "username": "testuser",
                "display_name": "Test User",
                "avatar_url": null,
                "bio": null,
                "favorite_books": [],
                "created_at": "2026-01-01T00:00:00Z"
            }
        }
        """
        let data = json.data(using: .utf8)!
        let auth = try decoder.decode(AuthResponse.self, from: data)

        XCTAssertEqual(auth.accessToken, "eyJhbGciOiJIUzI1NiJ9.test.payload")
        XCTAssertEqual(auth.refreshToken, "refresh-token-value")
        XCTAssertEqual(auth.user.username, "testuser")
    }

    func testSignupRequestEncoding() throws {
        let request = SignupRequest(
            email: "test@example.com",
            password: "securepass123",
            username: "newuser"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["email"] as? String, "test@example.com")
        XCTAssertEqual(json["username"] as? String, "newuser")
    }

    func testLoginRequestEncoding() throws {
        let request = LoginRequest(
            email: "test@example.com",
            password: "securepass123"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["email"] as? String, "test@example.com")
    }

    // MARK: - Review

    func testDecodeReview() throws {
        let json = """
        {
            "id": "99999999-9999-9999-9999-999999999999",
            "user": {
                "id": "11111111-1111-1111-1111-111111111111",
                "username": "reviewer"
            },
            "rating": 4.5,
            "review_text": "A masterpiece of modern literature.",
            "has_spoilers": true,
            "created_at": "2026-02-15T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let review = try decoder.decode(Review.self, from: data)

        XCTAssertEqual(review.user.username, "reviewer")
        XCTAssertEqual(review.rating, 4.5, accuracy: 0.01)
        XCTAssertEqual(review.reviewText, "A masterpiece of modern literature.")
        XCTAssertTrue(review.hasSpoilers)
    }

    func testDecodeReviewWithoutText() throws {
        let json = """
        {
            "id": "99999999-9999-9999-9999-999999999999",
            "user": {"id": "11111111-1111-1111-1111-111111111111", "username": "rater"},
            "rating": 3.0,
            "review_text": null,
            "has_spoilers": false,
            "created_at": "2026-02-15T12:00:00Z"
        }
        """
        let data = json.data(using: .utf8)!
        let review = try decoder.decode(Review.self, from: data)

        XCTAssertNil(review.reviewText)
        XCTAssertEqual(review.rating, 3.0)
    }
}
