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
    let userID: UUID
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
