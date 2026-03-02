import Foundation
import Combine

@Observable
final class SearchViewModel {
    var query = ""
    private(set) var results: [Book] = []
    private(set) var isSearching = false
    private(set) var hasSearched = false
    private(set) var error: Error?

    private let bookService = BookService.shared
    private var searchTask: Task<Void, Never>?

    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            hasSearched = false
            return
        }

        searchTask?.cancel()
        searchTask = Task { @MainActor in
            // 300ms debounce prevents firing a search on every keystroke while still feeling responsive.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            error = nil

            do {
                let response = try await bookService.search(query: trimmed)
                guard !Task.isCancelled else { return }
                results = response.items
                hasSearched = true
            } catch is CancellationError {
                // Expected
            } catch {
                self.error = error
            }

            isSearching = false
        }
    }

    func clear() {
        query = ""
        results = []
        hasSearched = false
        searchTask?.cancel()
    }
}
