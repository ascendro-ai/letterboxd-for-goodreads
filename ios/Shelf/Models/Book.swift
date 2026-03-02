import Foundation

// MARK: - Book / Work

struct Book: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let originalTitle: String?
    let description: String?
    let firstPublishedYear: Int?
    let authors: [Author]
    let subjects: [String]
    let coverImageURL: String?
    let averageRating: Double?
    let ratingsCount: Int
    let editionsCount: Int
    let bookshopURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description, authors, subjects
        case originalTitle = "original_title"
        case firstPublishedYear = "first_published_year"
        case coverImageURL = "cover_image_url"
        case averageRating = "average_rating"
        case ratingsCount = "ratings_count"
        case editionsCount = "editions_count"
        case bookshopURL = "bookshop_url"
    }
}

// MARK: - Author

struct Author: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let bio: String?
    let photoURL: String?

    enum CodingKeys: String, CodingKey {
        case id, name, bio
        case photoURL = "photo_url"
    }
}

// MARK: - Edition

struct Edition: Codable, Identifiable, Hashable {
    let id: UUID
    let workID: UUID
    let isbn10: String?
    let isbn13: String?
    let publisher: String?
    let publishDate: String?
    let pageCount: Int?
    let format: BookFormat?
    let language: String?
    let coverImageURL: String?

    enum CodingKeys: String, CodingKey {
        case id, publisher, language, format
        case workID = "work_id"
        case isbn10 = "isbn_10"
        case isbn13 = "isbn_13"
        case publishDate = "publish_date"
        case pageCount = "page_count"
        case coverImageURL = "cover_image_url"
    }
}

enum BookFormat: String, Codable, CaseIterable {
    case hardcover
    case paperback
    case ebook
    case audiobook
}
