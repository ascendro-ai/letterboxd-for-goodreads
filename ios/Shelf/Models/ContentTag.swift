/// Content warning and mood tag models matching backend schemas.

import Foundation

struct ContentTag: Codable, Identifiable {
    let id: UUID
    let tagName: String
    let tagType: String
    let voteCount: Int
    let isConfirmed: Bool
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case tagType = "tag_type"
        case voteCount = "vote_count"
        case isConfirmed = "is_confirmed"
        case displayName = "display_name"
    }

    var isContentWarning: Bool { tagType == "content_warning" }
    var isMood: Bool { tagType == "mood" }
}

struct AvailableTags: Codable {
    let contentWarnings: [String]
    let moods: [String]

    enum CodingKeys: String, CodingKey {
        case contentWarnings = "content_warnings"
        case moods
    }
}

struct VoteTagRequest: Codable {
    let tagName: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
    }
}
