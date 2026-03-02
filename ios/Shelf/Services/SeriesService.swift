import Foundation

@Observable
final class SeriesService {
    static let shared = SeriesService()
    private let api = APIClient.shared

    private init() {}

    func getSeries(id: UUID) async throws -> Series {
        try await api.request(.get, path: "/series/\(id.uuidString)")
    }

    func getSeriesProgress(id: UUID) async throws -> SeriesProgress {
        try await api.request(.get, path: "/series/\(id.uuidString)/progress")
    }

    func getBookSeries(workID: UUID) async throws -> [Series] {
        try await api.request(.get, path: "/books/\(workID.uuidString)/series")
    }
}
