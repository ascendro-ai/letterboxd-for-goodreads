import Foundation
import SwiftData

// MARK: - SwiftData Models for Offline Cache

@Model
final class CachedBook {
    @Attribute(.unique) var bookID: UUID
    var title: String
    var authorName: String?
    var coverImageURL: String?
    var averageRating: Double?
    var cachedAt: Date

    init(bookID: UUID, title: String, authorName: String?, coverImageURL: String?, averageRating: Double?) {
        self.bookID = bookID
        self.title = title
        self.authorName = authorName
        self.coverImageURL = coverImageURL
        self.averageRating = averageRating
        self.cachedAt = Date()
    }

    convenience init(from book: Book) {
        self.init(
            bookID: book.id,
            title: book.title,
            authorName: book.authors.first?.name,
            coverImageURL: book.coverImageURL,
            averageRating: book.averageRating
        )
    }
}

@Model
final class CachedUserBook {
    @Attribute(.unique) var userBookID: UUID
    var workID: UUID
    var status: String
    var rating: Double?
    var reviewText: String?
    var hasSpoilers: Bool
    var cachedAt: Date

    init(userBookID: UUID, workID: UUID, status: String, rating: Double?, reviewText: String?, hasSpoilers: Bool) {
        self.userBookID = userBookID
        self.workID = workID
        self.status = status
        self.rating = rating
        self.reviewText = reviewText
        self.hasSpoilers = hasSpoilers
        self.cachedAt = Date()
    }

    convenience init(from userBook: UserBook) {
        self.init(
            userBookID: userBook.id,
            workID: userBook.workID,
            status: userBook.status.rawValue,
            rating: userBook.rating,
            reviewText: userBook.reviewText,
            hasSpoilers: userBook.hasSpoilers
        )
    }
}

// MARK: - Pending Action (offline queue)

@Model
final class PendingAction {
    @Attribute(.unique) var id: UUID
    var actionType: String  // "log_book", "update_book", "delete_book"
    var payload: Data       // JSON-encoded request body
    var createdAt: Date
    var retryCount: Int

    init(actionType: String, payload: Data) {
        self.id = UUID()
        self.actionType = actionType
        self.payload = payload
        self.createdAt = Date()
        self.retryCount = 0
    }
}

// MARK: - Offline Store

@Observable
final class OfflineStore {
    static let shared = OfflineStore()

    let container: ModelContainer

    private init() {
        do {
            let schema = Schema([CachedBook.self, CachedUserBook.self, PendingAction.self])
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            self.container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    // MARK: - Cache Books

    @MainActor
    func cacheBook(_ book: Book) {
        let context = container.mainContext
        let cached = CachedBook(from: book)
        context.insert(cached)
        try? context.save()
    }

    @MainActor
    func cacheBooks(_ books: [Book]) {
        let context = container.mainContext
        for book in books {
            context.insert(CachedBook(from: book))
        }
        try? context.save()
    }

    // MARK: - Queue Offline Actions

    @MainActor
    func queueAction(type: String, payload: some Encodable) {
        let context = container.mainContext
        if let data = try? JSONEncoder().encode(payload) {
            let action = PendingAction(actionType: type, payload: data)
            context.insert(action)
            try? context.save()
        }
    }

    @MainActor
    func getPendingActions() -> [PendingAction] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<PendingAction>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    func removePendingAction(_ action: PendingAction) {
        let context = container.mainContext
        context.delete(action)
        try? context.save()
    }
}
