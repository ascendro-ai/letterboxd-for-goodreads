import Foundation

@Observable
final class UserBookService {
    static let shared = UserBookService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Log Book

    func logBook(_ request: LogBookRequest) async throws -> UserBook {
        try await api.request(.post, path: "/me/books", body: request)
    }

    // MARK: - Update Book

    func updateBook(id: UUID, request: UpdateBookRequest) async throws -> UserBook {
        try await api.request(.patch, path: "/me/books/\(id.uuidString)", body: request)
    }

    // MARK: - Remove Book

    func removeBook(id: UUID) async throws {
        try await api.request(.delete, path: "/me/books/\(id.uuidString)")
    }

    // MARK: - My Books

    func getMyBooks(status: ReadingStatus? = nil, cursor: String? = nil) async throws -> PaginatedResponse<UserBook> {
        var queryItems: [URLQueryItem] = []
        if let status { queryItems.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/me/books", queryItems: queryItems)
    }

    // MARK: - Other User's Books

    func getUserBooks(userID: UUID, status: ReadingStatus? = nil, cursor: String? = nil) async throws -> PaginatedResponse<UserBook> {
        var queryItems: [URLQueryItem] = []
        if let status { queryItems.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/users/\(userID.uuidString)/books", queryItems: queryItems)
    }
}
