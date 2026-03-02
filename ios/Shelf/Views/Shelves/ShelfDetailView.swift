import SwiftUI

struct ShelfDetailView: View {
    let shelf: Shelf
    let userID: UUID?

    @State private var books: [UserBook] = []
    @State private var isLoading = false
    @State private var error: Error?

    private let shelfService = ShelfService.shared

    var body: some View {
        Group {
            if isLoading && books.isEmpty {
                LoadingStateView()
            } else if let error, books.isEmpty {
                ErrorStateView(error: error) {
                    Task { await load() }
                }
            } else if books.isEmpty {
                EmptyStateView(
                    icon: "books.vertical",
                    title: "Empty shelf",
                    message: "No books on this shelf yet."
                )
            } else {
                booksList
            }
        }
        .navigationTitle(shelf.name)
        .task { await load() }
    }

    private var booksList: some View {
        List(books) { userBook in
            if let book = userBook.book {
                NavigationLink(value: book) {
                    BookCard(book: book, size: .medium)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let id = userID ?? AuthService.shared.currentUser?.id ?? UUID()
            let response = try await shelfService.getShelfDetail(userID: id, shelfID: shelf.id)
            books = response.items
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
