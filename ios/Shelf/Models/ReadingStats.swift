/// Reading statistics models matching backend stats schemas.

import Foundation

struct MonthlyCount: Codable, Identifiable {
    var id: Int { month }
    let month: Int
    let count: Int
}

struct RatingDistribution: Codable, Identifiable {
    var id: Double { rating }
    let rating: Double
    let count: Int
}

struct YearlyStats: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let booksRead: Int
    let pagesRead: Int?
    let averageRating: Double?
    let monthlyBreakdown: [MonthlyCount]?
    let ratingDistribution: [RatingDistribution]?
    let topGenres: [String]?

    enum CodingKeys: String, CodingKey {
        case year
        case booksRead = "books_read"
        case pagesRead = "pages_read"
        case averageRating = "average_rating"
        case monthlyBreakdown = "monthly_breakdown"
        case ratingDistribution = "rating_distribution"
        case topGenres = "top_genres"
    }
}

struct ReadingStats: Codable {
    let totalBooks: Int
    let totalRead: Int
    let totalReading: Int
    let totalWantToRead: Int
    let totalDidNotFinish: Int
    let averageRating: Double?
    let currentYearStats: YearlyStats
    let yearlyStats: [YearlyStats]

    enum CodingKeys: String, CodingKey {
        case totalBooks = "total_books"
        case totalRead = "total_read"
        case totalReading = "total_reading"
        case totalWantToRead = "total_want_to_read"
        case totalDidNotFinish = "total_did_not_finish"
        case averageRating = "average_rating"
        case currentYearStats = "current_year_stats"
        case yearlyStats = "yearly_stats"
    }
}
