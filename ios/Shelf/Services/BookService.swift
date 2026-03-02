import Foundation

@Observable
final class BookService {
    static let shared = BookService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Search

    func search(query: String, cursor: String? = nil, limit: Int = 20) async throws -> PaginatedResponse<Book> {
        var queryItems = [URLQueryItem(name: "q", value: query)]
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        return try await api.request(.get, path: "/books/search", queryItems: queryItems)
    }

    // MARK: - Book Detail

    func getBook(id: UUID) async throws -> Book {
        try await api.request(.get, path: "/books/\(id.uuidString)")
    }

    // MARK: - ISBN Lookup

    func lookupISBN(_ isbn: String) async throws -> Book {
        try await api.request(.get, path: "/books/isbn/\(isbn)")
    }

    // MARK: - Reviews

    func getReviews(bookID: UUID, cursor: String? = nil) async throws -> PaginatedResponse<Review> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/books/\(bookID.uuidString)/reviews", queryItems: queryItems)
    }

    // MARK: - Similar Books

    func getSimilarBooks(bookID: UUID) async throws -> [Book] {
        try await api.request(.get, path: "/books/\(bookID.uuidString)/similar")
    }

    // MARK: - Popular

    func getPopular() async throws -> [Book] {
        try await api.request(.get, path: "/books/popular")
    }
}
