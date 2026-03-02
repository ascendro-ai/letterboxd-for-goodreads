import SwiftUI

struct ShelfDetailView: View {
    let shelf: Shelf
    let userID: UUID?

    @State private var books: [UserBook] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var displayMode: ProfileDisplayMode = .list

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
                booksContent
            }
        }
        .navigationTitle(shelf.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        displayMode = displayMode == .grid ? .list : .grid
                    }
                } label: {
                    Image(systemName: displayMode == .grid ? "list.bullet" : "square.grid.3x3")
                }
                .accessibilityLabel(displayMode == .grid ? "Switch to list view" : "Switch to grid view")
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var booksContent: some View {
        let booksWithCovers = books.compactMap(\.book)

        if displayMode == .grid {
            ScrollView {
                CoverGridView(books: booksWithCovers, columns: 3) { _ in }
                    .frame(minHeight: CGFloat(max(1, (booksWithCovers.count + 2) / 3)) * 180)
            }
        } else {
            List(books) { userBook in
                if let book = userBook.book {
                    NavigationLink(value: book) {
                        BookCard(book: book, size: .medium)
                    }
                }
            }
            .listStyle(.plain)
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
