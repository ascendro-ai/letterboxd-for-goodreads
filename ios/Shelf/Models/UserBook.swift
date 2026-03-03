/// Reading log entry tying a user to a work. Maps to the backend's UserBook model.
/// Rating uses half-star increments (0.5–5.0) to match Letterboxd-style granularity.

import Foundation

// MARK: - Reading Status

enum ReadingStatus: String, Codable, CaseIterable {
    case reading
    case read
    case wantToRead = "want_to_read"
    case didNotFinish = "did_not_finish"

    var displayName: String {
        switch self {
        case .reading: "Reading"
        case .read: "Read"
        case .wantToRead: "Want to Read"
        case .didNotFinish: "Did Not Finish"
        }
    }

    var iconName: String {
        switch self {
        case .reading: "book.fill"
        case .read: "checkmark.circle.fill"
        case .wantToRead: "bookmark.fill"
        case .didNotFinish: "xmark.circle.fill"
        }
    }
}

// MARK: - UserBook

struct UserBook: Codable, Identifiable, Hashable {
    let id: UUID
    let userID: UUID?
    let workID: UUID
    let status: ReadingStatus
    let rating: Double?
    let reviewText: String?
    let hasSpoilers: Bool
    let startedAt: Date?
    let finishedAt: Date?
    let isImported: Bool
    let isPrivate: Bool
    let createdAt: Date
    let updatedAt: Date

    // Populated on list endpoints
    let book: Book?

    enum CodingKeys: String, CodingKey {
        case id, status, rating, book
        case userID = "user_id"
        case workID = "work_id"
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case isImported = "is_imported"
        case isPrivate = "is_private"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decodeIfPresent(UUID.self, forKey: .userID)
        workID = try container.decode(UUID.self, forKey: .workID)
        status = try container.decode(ReadingStatus.self, forKey: .status)
        reviewText = try container.decodeIfPresent(String.self, forKey: .reviewText)
        hasSpoilers = try container.decodeIfPresent(Bool.self, forKey: .hasSpoilers) ?? false
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(Date.self, forKey: .finishedAt)
        isImported = try container.decodeIfPresent(Bool.self, forKey: .isImported) ?? false
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        book = try container.decodeIfPresent(Book.self, forKey: .book)
        // Backend returns rating as string "4.5" — parse flexibly
        if let doubleVal = try? container.decodeIfPresent(Double.self, forKey: .rating) {
            rating = doubleVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .rating) {
            rating = Double(strVal)
        } else {
            rating = nil
        }
    }
}

// MARK: - Log Book Request

struct LogBookRequest: Codable {
    let workID: UUID
    var status: ReadingStatus
    var rating: Double?
    var reviewText: String?
    var hasSpoilers: Bool = false
    var isPrivate: Bool = false
    var startedAt: Date?
    var finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status, rating
        case workID = "work_id"
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case isPrivate = "is_private"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }
}

struct UpdateBookRequest: Codable {
    var status: ReadingStatus?
    var rating: Double?
    var reviewText: String?
    var hasSpoilers: Bool?
    var isPrivate: Bool?
    var startedAt: Date?
    var finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case status, rating
        case reviewText = "review_text"
        case hasSpoilers = "has_spoilers"
        case isPrivate = "is_private"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }
}
