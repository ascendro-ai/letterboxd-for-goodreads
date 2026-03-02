import XCTest
import SwiftData
@testable import Shelf

final class OfflineStoreTests: XCTestCase {

    // MARK: - CachedBook Tests

    func testCachedBookFromBook() {
        let book = MockData.makeBook()
        let cached = CachedBook(from: book)

        XCTAssertEqual(cached.bookID, book.id)
        XCTAssertEqual(cached.title, book.title)
        XCTAssertEqual(cached.authorName, book.authors.first?.name)
        XCTAssertEqual(cached.averageRating, book.averageRating)
        XCTAssertNil(cached.coverImageURL)
    }

    func testCachedBookFromBookWithCover() {
        let book = MockData.makeBook(coverImageURL: "https://example.com/cover.webp")
        let cached = CachedBook(from: book)

        XCTAssertEqual(cached.coverImageURL, "https://example.com/cover.webp")
    }

    func testCachedBookFromBookNoAuthors() {
        let book = MockData.makeBook(authors: [])
        let cached = CachedBook(from: book)

        XCTAssertNil(cached.authorName)
    }

    // MARK: - CachedUserBook Tests

    func testCachedUserBookFromUserBook() {
        let userBook = MockData.makeUserBook()
        let cached = CachedUserBook(from: userBook)

        XCTAssertEqual(cached.userBookID, userBook.id)
        XCTAssertEqual(cached.workID, userBook.workID)
        XCTAssertEqual(cached.status, userBook.status.rawValue)
        XCTAssertEqual(cached.rating, userBook.rating)
        XCTAssertEqual(cached.reviewText, userBook.reviewText)
        XCTAssertFalse(cached.hasSpoilers)
    }

    func testCachedUserBookPreservesStatus() {
        for status in ReadingStatus.allCases {
            let userBook = MockData.makeUserBook(status: status)
            let cached = CachedUserBook(from: userBook)
            XCTAssertEqual(cached.status, status.rawValue,
                           "Status \(status) should be stored as its raw value")
        }
    }

    // MARK: - PendingAction Tests

    func testPendingActionCreation() {
        let payload = "{}".data(using: .utf8)!
        let action = PendingAction(actionType: "log_book", payload: payload)

        XCTAssertEqual(action.actionType, "log_book")
        XCTAssertEqual(action.retryCount, 0)
        XCTAssertNotNil(action.id)
    }

    func testPendingActionTypes() {
        let types = ["log_book", "update_book", "delete_book"]

        for type in types {
            let payload = "{}".data(using: .utf8)!
            let action = PendingAction(actionType: type, payload: payload)
            XCTAssertEqual(action.actionType, type)
        }
    }

    func testPendingActionPayloadEncoding() throws {
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
        let payload = try encoder.encode(request)
        let action = PendingAction(actionType: "log_book", payload: payload)

        // Verify payload round-trips
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(LogBookRequest.self, from: action.payload)
        XCTAssertEqual(decoded.workID, MockData.workID)
        XCTAssertEqual(decoded.status, .read)
        XCTAssertEqual(decoded.rating, 4.0)
    }
}
