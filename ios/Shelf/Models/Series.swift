import Foundation

// MARK: - Series

struct Series: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let totalBooks: Int?
    let isComplete: Bool
    let coverImageURL: String?
    let works: [SeriesWorkItem]

    enum CodingKeys: String, CodingKey {
        case id, name, description, works
        case totalBooks = "total_books"
        case isComplete = "is_complete"
        case coverImageURL = "cover_image_url"
    }
}

// MARK: - Series Work Item

struct SeriesWorkItem: Codable, Identifiable, Hashable {
    var id: UUID { workID }
    let position: Double
    let isMainEntry: Bool
    let workID: UUID
    let title: String
    let authors: [String]
    let coverImageURL: String?
    let userStatus: String?

    enum CodingKeys: String, CodingKey {
        case position, title, authors
        case isMainEntry = "is_main_entry"
        case workID = "work_id"
        case coverImageURL = "cover_image_url"
        case userStatus = "user_status"
    }
}

// MARK: - Series Progress

struct SeriesProgress: Codable {
    let seriesID: UUID
    let seriesName: String
    let totalMainEntries: Int
    let readCount: Int
    let readingCount: Int
    let progressPercent: Double

    enum CodingKeys: String, CodingKey {
        case seriesID = "series_id"
        case seriesName = "series_name"
        case totalMainEntries = "total_main_entries"
        case readCount = "read_count"
        case readingCount = "reading_count"
        case progressPercent = "progress_percent"
    }
}
