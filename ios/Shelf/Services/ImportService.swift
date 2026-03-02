import Foundation

@Observable
final class ImportService {
    static let shared = ImportService()
    private let api = APIClient.shared

    private init() {}

    // MARK: - Upload CSV

    func importGoodreads(csvData: Data) async throws -> ImportStatus {
        try await api.upload(path: "/me/import/goodreads", fileData: csvData, fileName: "goodreads_library_export.csv")
    }

    func importStoryGraph(csvData: Data) async throws -> ImportStatus {
        try await api.upload(path: "/me/import/storygraph", fileData: csvData, fileName: "storygraph_export.csv")
    }

    // MARK: - Check Progress

    func getImportStatus() async throws -> ImportStatus {
        try await api.request(.get, path: "/me/import/status")
    }
}
