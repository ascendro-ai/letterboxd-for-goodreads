import Foundation

@Observable
final class ShelfService {
    static let shared = ShelfService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - CRUD

    func createShelf(_ request: CreateShelfRequest) async throws -> Shelf {
        try await api.request(.post, path: "/me/shelves", body: request)
    }

    func getMyShelves() async throws -> [Shelf] {
        try await api.request(.get, path: "/me/shelves")
    }

    func updateShelf(id: UUID, request: UpdateShelfRequest) async throws -> Shelf {
        try await api.request(.patch, path: "/me/shelves/\(id.uuidString)", body: request)
    }

    func deleteShelf(id: UUID) async throws {
        try await api.request(.delete, path: "/me/shelves/\(id.uuidString)")
    }

    // MARK: - Shelf Books

    func addBookToShelf(shelfID: UUID, userBookID: UUID) async throws {
        let request = AddBookToShelfRequest(userBookID: userBookID)
        try await api.request(.post, path: "/me/shelves/\(shelfID.uuidString)/books", body: request)
    }

    func removeBookFromShelf(shelfID: UUID, userBookID: UUID) async throws {
        try await api.request(.delete, path: "/me/shelves/\(shelfID.uuidString)/books/\(userBookID.uuidString)")
    }

    // MARK: - Other User's Shelves

    func getUserShelves(userID: UUID) async throws -> [Shelf] {
        try await api.request(.get, path: "/users/\(userID.uuidString)/shelves")
    }

    func getShelfDetail(userID: UUID, shelfID: UUID, cursor: String? = nil) async throws -> PaginatedResponse<UserBook> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        return try await api.request(.get, path: "/users/\(userID.uuidString)/shelves/\(shelfID.uuidString)", queryItems: queryItems)
    }
}
