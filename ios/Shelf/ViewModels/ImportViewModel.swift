import Foundation
import UniformTypeIdentifiers

@Observable
final class ImportViewModel {
    private(set) var importStatus: ImportStatus?
    private(set) var isUploading = false
    private(set) var isPolling = false
    private(set) var error: Error?

    var selectedSource: ImportSource = .goodreads

    private let importService = ImportService.shared
    private var pollTask: Task<Void, Never>?

    var isComplete: Bool {
        importStatus?.status == .completed || importStatus?.status == .failed
    }

    var progressText: String {
        guard let status = importStatus else { return "" }
        return "\(status.matched) matched, \(status.needsReview) need review, \(status.unmatched) unmatched"
    }

    @MainActor
    func uploadCSV(data: Data) async {
        isUploading = true
        error = nil

        do {
            let status: ImportStatus
            switch selectedSource {
            case .goodreads:
                status = try await importService.importGoodreads(csvData: data)
            case .storygraph:
                status = try await importService.importStoryGraph(csvData: data)
            }
            importStatus = status
            startPolling()
        } catch {
            self.error = error
        }

        isUploading = false
    }

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            isPolling = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }

                do {
                    let status = try await importService.getImportStatus()
                    importStatus = status
                    if status.status == .completed || status.status == .failed {
                        break
                    }
                } catch {
                    break
                }
            }
            isPolling = false
        }
    }

    func stopPolling() {
        pollTask?.cancel()
    }
}
