import Foundation

@Observable
final class BookDetailViewModel {
    let bookID: UUID

    private(set) var book: Book?
    private(set) var reviews: [Review] = []
    private(set) var similarBooks: [Book] = []
    private(set) var userBook: UserBook?
    private(set) var isLoading = false
    private(set) var error: Error?

    private let bookService = BookService.shared
    private let userBookService = UserBookService.shared

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

            let (b, r, s) = try await (bookResult, reviewsResult, similarResult)
            book = b
            reviews = r.items
            similarBooks = s
        } catch {
            self.error = error
        }

        isLoading = false
    }

    @MainActor
    func logBook(request: LogBookRequest) async throws {
        let result = try await userBookService.logBook(request)
        userBook = result
    }

    @MainActor
    func updateBook(request: UpdateBookRequest) async throws {
        guard let id = userBook?.id else { return }
        let result = try await userBookService.updateBook(id: id, request: request)
        userBook = result
    }

    @MainActor
    func removeBook() async throws {
        guard let id = userBook?.id else { return }
        try await userBookService.removeBook(id: id)
        userBook = nil
    }
}
