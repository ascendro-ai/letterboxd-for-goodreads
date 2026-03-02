import Foundation

@Observable
final class BookDetailViewModel {
    let bookID: UUID

    private(set) var book: Book?
    private(set) var reviews: [Review] = []
    private(set) var similarBooks: [Book] = []
    private(set) var userBook: UserBook?
    private(set) var seriesList: [Series] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    private let bookService = BookService.shared
    private let userBookService = UserBookService.shared
    private let seriesService = SeriesService.shared
    private let offlineStore = OfflineStore.shared
    private let syncService = SyncService.shared

    init(bookID: UUID) {
        self.bookID = bookID
    }

    @MainActor
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            async let bookResult = bookService.getBook(id: bookID)
            async let reviewsResult = bookService.getReviews(bookID: bookID)
            async let similarResult = bookService.getSimilarBooks(bookID: bookID)
            async let seriesResult = seriesService.getBookSeries(workID: bookID)

            let (b, r, s, series) = try await (bookResult, reviewsResult, similarResult, seriesResult)
            book = b
            reviews = r.items
            similarBooks = s
            seriesList = series

            // Cache the book for offline use
            offlineStore.cacheBook(b)
        } catch {
            // Try offline cache fallback
            if let cached = offlineStore.getCachedBook(id: bookID) {
                book = Book(
                    id: cached.bookID,
                    title: cached.title,
                    originalTitle: nil,
                    description: nil,
                    firstPublishedYear: nil,
                    authors: cached.authorName.map { [Author(id: UUID(), name: $0, bio: nil, photoURL: nil)] } ?? [],
                    subjects: [],
                    coverImageURL: cached.coverImageURL,
                    averageRating: cached.averageRating,
                    ratingsCount: 0,
                    editionsCount: 0,
                    bookshopURL: nil
                )
            }
            self.error = error
        }

        isLoading = false
    }

    @MainActor
    func logBook(request: LogBookRequest) async throws {
        if syncService.isOnline {
            let result = try await userBookService.logBook(request)
            userBook = result
        } else {
            // Queue for offline sync
            offlineStore.queueAction(type: "log_book", payload: request)
        }
    }

    @MainActor
    func updateBook(request: UpdateBookRequest) async throws {
        guard let id = userBook?.id else { return }
        if syncService.isOnline {
            let result = try await userBookService.updateBook(id: id, request: request)
            userBook = result
        } else {
            let payload = UpdateActionPayload(id: id, request: request)
            offlineStore.queueAction(type: "update_book", payload: payload)
        }
    }

    @MainActor
    func removeBook() async throws {
        guard let id = userBook?.id else { return }
        if syncService.isOnline {
            try await userBookService.removeBook(id: id)
            userBook = nil
        } else {
            offlineStore.queueAction(type: "delete_book", payload: IDWrapper(id: id))
            userBook = nil
        }
    }
}
