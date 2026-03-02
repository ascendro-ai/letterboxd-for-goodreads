/// View model for reading statistics.

import Foundation

@Observable
final class StatsViewModel {
    private(set) var stats: ReadingStats?
    private(set) var isLoading = false
    private(set) var error: String?

    private let userID: UUID?

    /// Pass nil for the current user's stats.
    init(userID: UUID? = nil) {
        self.userID = userID
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            let path: String
            if let userID {
                path = "/users/\(userID.uuidString)/stats"
            } else {
                path = "/me/stats"
            }
            stats = try await APIClient.shared.request(.get, path: path)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}
