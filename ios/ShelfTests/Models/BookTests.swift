import XCTest
@testable import Shelf

final class BookTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testDecodeBookFromJSON() throws {
        let data = MockData.bookJSON.data(using: .utf8)!
        let book = try decoder.decode(Book.self, from: data)

        XCTAssertEqual(book.id, MockData.workID)
        XCTAssertEqual(book.title, "The Great Gatsby")
        XCTAssertEqual(book.authors.count, 1)
        XCTAssertEqual(book.authors.first?.name, "F. Scott Fitzgerald")
        XCTAssertEqual(book.firstPublishedYear, 1925)
        XCTAssertEqual(book.averageRating, 4.2, accuracy: 0.01)
        XCTAssertEqual(book.ratingsCount, 1523)
        XCTAssertEqual(book.editionsCount, 12)
        XCTAssertNil(book.coverImageURL)
        XCTAssertNil(book.originalTitle)
        XCTAssertNil(book.bookshopURL)
    }

    func testDecodeBookWithCoverURL() throws {
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "title": "Test Book",
            "original_title": "Original Title",
            "description": null,
            "first_published_year": null,
            "authors": [{"id": "44444444-4444-4444-4444-444444444444", "name": "Author"}],
            "subjects": [],
            "cover_image_url": "https://covers.shelf.app/thumb/abc.webp",
            "average_rating": null,
            "ratings_count": 0,
            "editions_count": 1,
            "bookshop_url": "https://bookshop.org/test"
        }
        """
        let data = json.data(using: .utf8)!
        let book = try decoder.decode(Book.self, from: data)

        XCTAssertEqual(book.coverImageURL, "https://covers.shelf.app/thumb/abc.webp")
        XCTAssertEqual(book.originalTitle, "Original Title")
        XCTAssertEqual(book.bookshopURL, "https://bookshop.org/test")
        XCTAssertNil(book.description)
        XCTAssertNil(book.firstPublishedYear)
        XCTAssertNil(book.averageRating)
    }

    func testDecodeBookWithMultipleAuthors() throws {
        let json = """
        {
            "id": "33333333-3333-3333-3333-333333333333",
            "title": "Good Omens",
            "authors": [
                {"id": "44444444-4444-4444-4444-444444444444", "name": "Terry Pratchett"},
                {"id": "55555555-5555-5555-5555-555555555555", "name": "Neil Gaiman"}
            ],
            "subjects": ["fantasy", "humor"],
            "ratings_count": 500,
            "editions_count": 3
        }
        """
        let data = json.data(using: .utf8)!
        let book = try decoder.decode(Book.self, from: data)

        XCTAssertEqual(book.authors.count, 2)
        XCTAssertEqual(book.authors[0].name, "Terry Pratchett")
        XCTAssertEqual(book.authors[1].name, "Neil Gaiman")
    }

    func testEncodeBookRoundTrip() throws {
        let book = MockData.makeBook()
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(book)

        let decoded = try decoder.decode(Book.self, from: data)
        XCTAssertEqual(decoded.id, book.id)
        XCTAssertEqual(decoded.title, book.title)
        XCTAssertEqual(decoded.authors.count, book.authors.count)
        XCTAssertEqual(decoded.ratingsCount, book.ratingsCount)
    }

    func testBookHashable() {
        let book1 = MockData.makeBook()
        let book2 = MockData.makeBook()
        let book3 = MockData.makeBook(id: UUID(), title: "Different")

        XCTAssertEqual(book1, book2)
        XCTAssertNotEqual(book1, book3)

        var set: Set<Book> = [book1, book2, book3]
        XCTAssertEqual(set.count, 2)
    }

    func testDecodeAuthor() throws {
        let json = """
        {
            "id": "44444444-4444-4444-4444-444444444444",
            "name": "Ursula K. Le Guin",
            "bio": "American author of science fiction and fantasy.",
            "photo_url": "https://example.com/photo.jpg"
        }
        """
        let data = json.data(using: .utf8)!
        let author = try decoder.decode(Author.self, from: data)

        XCTAssertEqual(author.name, "Ursula K. Le Guin")
        XCTAssertEqual(author.bio, "American author of science fiction and fantasy.")
        XCTAssertEqual(author.photoURL, "https://example.com/photo.jpg")
    }

    func testDecodeEdition() throws {
        let json = """
        {
            "id": "99999999-9999-9999-9999-999999999999",
            "work_id": "33333333-3333-3333-3333-333333333333",
            "isbn10": "0743273567",
            "isbn13": "9780743273565",
            "publisher": "Scribner",
            "publish_date": "2004",
            "page_count": 180,
            "format": "paperback",
            "language": "en",
            "cover_image_url": null
        }
        """
        let data = json.data(using: .utf8)!
        let edition = try decoder.decode(Edition.self, from: data)

        XCTAssertEqual(edition.isbn13, "9780743273565")
        XCTAssertEqual(edition.isbn10, "0743273567")
        XCTAssertEqual(edition.publisher, "Scribner")
        XCTAssertEqual(edition.pageCount, 180)
        XCTAssertEqual(edition.format, .paperback)
        XCTAssertEqual(edition.language, "en")
    }

    func testBookFormatCases() {
        let allCases = BookFormat.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.hardcover))
        XCTAssertTrue(allCases.contains(.paperback))
        XCTAssertTrue(allCases.contains(.ebook))
        XCTAssertTrue(allCases.contains(.audiobook))
    }
}
