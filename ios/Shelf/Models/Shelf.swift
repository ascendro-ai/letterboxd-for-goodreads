import Foundation

struct Shelf: Codable, Identifiable, Hashable {
    let id: UUID
    let userID: UUID?
    let name: String
    let slug: String
    let description: String?
    let isPublic: Bool
    let displayOrder: Int
    let booksCount: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description
        case userID = "user_id"
        case isPublic = "is_public"
        case displayOrder = "display_order"
        case booksCount = "book_count"
        case createdAt = "created_at"
    }
}

struct CreateShelfRequest: Codable {
    let name: String
    var description: String?
    var isPublic: Bool = true

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPublic = "is_public"
    }
}

struct UpdateShelfRequest: Codable {
    var name: String?
    var description: String?
    var isPublic: Bool?
    var displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPublic = "is_public"
        case displayOrder = "display_order"
    }
}

struct AddBookToShelfRequest: Codable {
    let userBookID: UUID

    enum CodingKeys: String, CodingKey {
        case userBookID = "user_book_id"
    }
}
