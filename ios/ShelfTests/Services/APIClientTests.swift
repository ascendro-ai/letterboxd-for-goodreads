import XCTest
@testable import Shelf

final class APIClientTests: XCTestCase {

    func testAPIClientSingleton() {
        let client1 = APIClient.shared
        let client2 = APIClient.shared
        XCTAssertTrue(client1 === client2)
    }

    func testAPIErrorDescriptions() {
        // Each API error variant should have a description
        let errors: [APIError] = [
            .invalidURL,
            .unauthorized,
            .forbidden,
            .notFound,
            .conflict("Conflict message"),
            .validationError("Validation error"),
            .rateLimited,
            .serverError,
            .networkError(NSError(domain: "test", code: 0)),
            .decodingError(NSError(domain: "test", code: 0)),
            .apiError(code: "TEST", message: "Test error"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                           "\(error) should have a description")
            XCTAssertFalse(error.errorDescription!.isEmpty,
                          "\(error) description should not be empty")
        }
    }

    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
    }

    func testPaginatedResponseDecoding() throws {
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
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(PaginatedResponse<Book>.self, from: data)

        XCTAssertEqual(response.items.count, 1)
        XCTAssertTrue(response.hasMore)
        XCTAssertNotNil(response.nextCursor)
    }

    func testErrorResponseDecoding() throws {
        let json = """
        {
            "error": {
                "code": "REVIEW_FLAGGED",
                "message": "Your review was flagged."
            }
        }
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let errorResponse = try decoder.decode(APIErrorResponse.self, from: data)
        XCTAssertEqual(errorResponse.error.code, "REVIEW_FLAGGED")
        XCTAssertEqual(errorResponse.error.message, "Your review was flagged.")
    }

    func testMockAPIClientRegistersResponses() async throws {
        let mock = MockAPIClient()
        let book = MockData.makeBook()
        mock.register(path: "/books/search", response: [book])

        let result: [Book] = try await mock.request(.get, path: "/books/search")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "The Great Gatsby")
    }

    func testMockAPIClientLogsRequests() async {
        let mock = MockAPIClient()
        mock.register(path: "/me", response: MockData.makeUser())

        let _: User = try! await mock.request(.get, path: "/me")

        XCTAssertEqual(mock.requestLog.count, 1)
        XCTAssertEqual(mock.requestLog[0].method, "GET")
        XCTAssertEqual(mock.requestLog[0].path, "/me")
    }

    func testMockAPIClientThrowsOnMissingResponse() async {
        let mock = MockAPIClient()

        do {
            let _: User = try await mock.request(.get, path: "/nonexistent")
            XCTFail("Should have thrown an error")
        } catch {
            // Expected: APIError.notFound
        }
    }

    func testMockAPIClientThrowsRegisteredError() async {
        let mock = MockAPIClient()
        mock.registerError(path: "/error", error: APIError.serverError)

        do {
            let _: User = try await mock.request(.get, path: "/error")
            XCTFail("Should have thrown an error")
        } catch let error as APIError {
            if case .serverError = error {
                // Expected
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
