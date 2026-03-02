import Foundation

/// Handles deep links and shared URLs, resolving them to book IDs for navigation.
/// Supports the `shelf://` URL scheme and universal links.
@Observable
final class DeepLinkHandler {
    static let shared = DeepLinkHandler()

    var pendingBookID: UUID?
    var pendingSearchQuery: String?

    private let bookService = BookService.shared

    private init() {}

    /// Process an incoming URL. Supports:
    /// - `shelf://book/isbn/{isbn}` — look up ISBN
    /// - `shelf://book/{uuid}` — direct book ID
    /// - `shelf://search?q={query}` — search query
    /// - https URLs from share extension
    @MainActor
    func handle(_ url: URL) {
        if url.scheme == "shelf" {
            handleShelfURL(url)
        } else {
            handleWebURL(url)
        }
    }

    @MainActor
    private func handleShelfURL(_ url: URL) {
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        // shelf://book/isbn/{isbn}
        if pathComponents.count >= 2 && pathComponents[0] == "book" && pathComponents[1] == "isbn" {
            let isbn = pathComponents.count > 2 ? pathComponents[2] : ""
            guard !isbn.isEmpty else { return }
            Task { await lookupISBN(isbn) }
            return
        }

        // shelf://book/{uuid}
        if pathComponents.count >= 1 && pathComponents[0] == "book" {
            let idString = pathComponents.count > 1 ? pathComponents[1] : ""
            if let uuid = UUID(uuidString: idString) {
                pendingBookID = uuid
                return
            }
        }

        // shelf://search?q={query}
        if url.host == "search" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let query = components.queryItems?.first(where: { $0.name == "q" })?.value {
                pendingSearchQuery = query
            }
        }
    }

    @MainActor
    private func handleWebURL(_ url: URL) {
        let identifier = BookIdentifier.extract(from: url)
        switch identifier {
        case .isbn(let isbn):
            Task { await lookupISBN(isbn) }
        case .goodreadsID, .amazonASIN, .openLibraryWork, .rawURL:
            // For non-ISBN identifiers, fall back to search with the URL
            pendingSearchQuery = url.absoluteString
        }
    }

    @MainActor
    private func lookupISBN(_ isbn: String) async {
        do {
            let book = try await bookService.lookupISBN(isbn)
            pendingBookID = book.id
        } catch {
            // Could not resolve ISBN — fail silently
        }
    }

    func clearPending() {
        pendingBookID = nil
        pendingSearchQuery = nil
    }
}
