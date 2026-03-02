import XCTest
@testable import Shelf

final class ShelfModelTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testDecodeShelf() throws {
        let data = MockData.shelfJSON.data(using: .utf8)!
        let shelf = try decoder.decode(Shelf.self, from: data)

        XCTAssertEqual(shelf.id, MockData.shelfID)
        XCTAssertEqual(shelf.userID, MockData.userID)
        XCTAssertEqual(shelf.name, "Favorites")
        XCTAssertEqual(shelf.slug, "favorites")
        XCTAssertEqual(shelf.description, "My favorite books")
        XCTAssertTrue(shelf.isPublic)
        XCTAssertEqual(shelf.displayOrder, 0)
        XCTAssertEqual(shelf.booksCount, 5)
    }

    func testDecodeShelfWithNulls() throws {
        let json = """
        {
            "id": "66666666-6666-6666-6666-666666666666",
            "user_id": "11111111-1111-1111-1111-111111111111",
            "name": "Private List",
            "slug": "private-list",
            "description": null,
            "is_public": false,
            "display_order": 1,
            "books_count": null,
            "created_at": null
        }
        """
        let data = json.data(using: .utf8)!
        let shelf = try decoder.decode(Shelf.self, from: data)

        XCTAssertEqual(shelf.name, "Private List")
        XCTAssertFalse(shelf.isPublic)
        XCTAssertNil(shelf.description)
        XCTAssertNil(shelf.booksCount)
        XCTAssertNil(shelf.createdAt)
    }

    func testCreateShelfRequestEncoding() throws {
        let request = CreateShelfRequest(
            name: "Sci-Fi Classics",
            description: "The best of science fiction",
            isPublic: true
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "Sci-Fi Classics")
        XCTAssertEqual(json["description"] as? String, "The best of science fiction")
        XCTAssertEqual(json["is_public"] as? Bool, true)
    }

    func testUpdateShelfRequestEncoding() throws {
        let request = UpdateShelfRequest(
            name: "Updated Name",
            description: nil,
            isPublic: false,
            displayOrder: 3
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["name"] as? String, "Updated Name")
        XCTAssertEqual(json["is_public"] as? Bool, false)
        XCTAssertEqual(json["display_order"] as? Int, 3)
    }

    func testAddBookToShelfRequestEncoding() throws {
        let request = AddBookToShelfRequest(userBookID: MockData.userBookID)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["user_book_id"] as? String, MockData.userBookID.uuidString)
    }

    func testShelfHashable() {
        let shelf1 = MockData.makeShelf()
        let shelf2 = MockData.makeShelf()
        let shelf3 = MockData.makeShelf(id: UUID(), name: "Different")

        XCTAssertEqual(shelf1, shelf2)
        XCTAssertNotEqual(shelf1, shelf3)
    }
}
