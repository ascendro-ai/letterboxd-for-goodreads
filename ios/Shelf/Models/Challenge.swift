import Foundation

// MARK: - Reading Challenge

struct ReadingChallenge: Codable, Identifiable, Hashable {
    let id: UUID
    let year: Int
    let goalCount: Int
    let currentCount: Int
    let isComplete: Bool
    let completedAt: Date?
    let createdAt: Date
    let books: [ChallengeBook]?

    enum CodingKeys: String, CodingKey {
        case id, year, books
        case goalCount = "goal_count"
        case currentCount = "current_count"
        case isComplete = "is_complete"
        case completedAt = "completed_at"
        case createdAt = "created_at"
    }

    var progressPercent: Double {
        guard goalCount > 0 else { return 0 }
        return min(1.0, Double(currentCount) / Double(goalCount))
    }
}

// MARK: - Challenge Book

struct ChallengeBook: Codable, Identifiable, Hashable {
    var id: UUID { userBookID }
    let userBookID: UUID
    let workTitle: String
    let authors: [String]
    let coverImageURL: String?
    let finishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case authors
        case userBookID = "user_book_id"
        case workTitle = "work_title"
        case coverImageURL = "cover_image_url"
        case finishedAt = "finished_at"
    }
}

// MARK: - Requests

struct CreateChallengeRequest: Codable {
    let year: Int
    let goalCount: Int

    enum CodingKeys: String, CodingKey {
        case year
        case goalCount = "goal_count"
    }
}

struct UpdateChallengeRequest: Codable {
    let goalCount: Int

    enum CodingKeys: String, CodingKey {
        case goalCount = "goal_count"
    }
}
