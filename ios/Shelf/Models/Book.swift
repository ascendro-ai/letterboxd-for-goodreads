import Foundation

// MARK: - Book / Work

struct Book: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let originalTitle: String?
    let description: String?
    let firstPublishedYear: Int?
    let authors: [Author]
    let subjects: [String]?
    let coverImageURL: String?
    let averageRating: Double?
    let ratingsCount: Int?
    let editionsCount: Int?
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

    init(id: UUID, title: String, originalTitle: String? = nil, description: String? = nil,
         firstPublishedYear: Int? = nil, authors: [Author] = [], subjects: [String]? = nil,
         coverImageURL: String? = nil, averageRating: Double? = nil, ratingsCount: Int? = nil,
         editionsCount: Int? = nil, bookshopURL: String? = nil) {
        self.id = id; self.title = title; self.originalTitle = originalTitle
        self.description = description; self.firstPublishedYear = firstPublishedYear
        self.authors = authors; self.subjects = subjects; self.coverImageURL = coverImageURL
        self.averageRating = averageRating; self.ratingsCount = ratingsCount
        self.editionsCount = editionsCount; self.bookshopURL = bookshopURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        originalTitle = try container.decodeIfPresent(String.self, forKey: .originalTitle)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        firstPublishedYear = try container.decodeIfPresent(Int.self, forKey: .firstPublishedYear)
        authors = try container.decodeIfPresent([Author].self, forKey: .authors) ?? []
        subjects = try container.decodeIfPresent([String].self, forKey: .subjects)
        coverImageURL = try container.decodeIfPresent(String.self, forKey: .coverImageURL)
        ratingsCount = try container.decodeIfPresent(Int.self, forKey: .ratingsCount)
        editionsCount = try container.decodeIfPresent(Int.self, forKey: .editionsCount)
        bookshopURL = try container.decodeIfPresent(String.self, forKey: .bookshopURL)
        // Backend returns averageRating as string "4.00" — parse flexibly
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .averageRating) {
            averageRating = doubleVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .averageRating) {
            averageRating = Double(strVal)
        } else {
            averageRating = nil
        }
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
