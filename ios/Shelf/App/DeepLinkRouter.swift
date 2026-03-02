/// Handles incoming shelf:// deep links and maps them to navigation destinations.
/// Routes: shelf://book/isbn/{isbn}, shelf://book/{id}, shelf://search?q={query},
/// shelf://user/{id}, shelf://notifications

import Foundation

@Observable
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    var pendingDestination: DeepLinkDestination?
    var selectedTab: ContentView.Tab?

    private let bookService = BookService.shared

    private init() {}

    /// Parse a shelf:// URL into a navigation destination.
    func handle(url: URL) {
        guard url.scheme == "shelf" else { return }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "book":
            if let first = pathComponents.first {
                if first == "isbn", let isbn = pathComponents.dropFirst().first {
                    // shelf://book/isbn/9780123456789
                    lookupISBN(String(isbn))
                } else if let bookID = UUID(uuidString: first) {
                    // shelf://book/{uuid}
                    pendingDestination = .bookDetail(bookID)
                    selectedTab = .search
                }
            }

        case "search":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let query = components.queryItems?.first(where: { $0.name == "q" })?.value {
                // shelf://search?q=some+query
                pendingDestination = .search(query)
                selectedTab = .search
            }

        case "user":
            if let first = pathComponents.first, let userID = UUID(uuidString: first) {
                pendingDestination = .userProfile(userID)
                selectedTab = .search
            }

        case "notifications":
            selectedTab = .notifications

        default:
            break
        }
    }

    private func lookupISBN(_ isbn: String) {
        Task {
            do {
                let book = try await bookService.lookupISBN(isbn)
                await MainActor.run {
                    pendingDestination = .bookDetail(book.id)
                    selectedTab = .search
                }
            } catch {
                // ISBN not found — fall back to search
                await MainActor.run {
                    pendingDestination = .search(isbn)
                    selectedTab = .search
                }
            }
        }
    }
}

enum DeepLinkDestination: Equatable {
    case bookDetail(UUID)
    case search(String)
    case userProfile(UUID)
}
