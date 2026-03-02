import SwiftUI

struct FavoriteBooksPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBooks: [Book] = []
    @State private var searchQuery = ""
    @State private var searchResults: [Book] = []
    @State private var isSearching = false

    let currentFavorites: [Book]
    let onSave: ([UUID]) -> Void

    private let maxFavorites = 4
    private let bookService = BookService.shared

    init(currentFavorites: [Book] = [], onSave: @escaping ([UUID]) -> Void) {
        self.currentFavorites = currentFavorites
        self.onSave = onSave
        self._selectedBooks = State(initialValue: currentFavorites)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected favorites
                if !selectedBooks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Favorites (\(selectedBooks.count)/\(maxFavorites))")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedBooks) { book in
                                    FavoriteBookChip(book: book) {
                                        selectedBooks.removeAll { $0.id == book.id }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                }

                // Search results
                List {
                    if isSearching {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if !searchQuery.isEmpty && searchResults.isEmpty {
                        ContentUnavailableView.search(text: searchQuery)
                    } else {
                        ForEach(searchResults) { book in
                            Button {
                                toggleBook(book)
                            } label: {
                                HStack(spacing: 12) {
                                    BookCoverImage(url: book.coverImageURL, size: CGSize(width: 40, height: 60))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(book.title)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(2)
                                        if let author = book.authors.first?.name {
                                            Text(author)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if selectedBooks.contains(where: { $0.id == book.id }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchQuery, prompt: "Search for your favorite books...")
            .onChange(of: searchQuery) {
                search()
            }
            .navigationTitle("Favorite Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedBooks.map(\.id))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func toggleBook(_ book: Book) {
        if let index = selectedBooks.firstIndex(where: { $0.id == book.id }) {
            selectedBooks.remove(at: index)
        } else if selectedBooks.count < maxFavorites {
            selectedBooks.append(book)
        }
    }

    private func search() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        Task {
            isSearching = true
            do {
                let response = try await bookService.search(query: trimmed)
                searchResults = response.items
            } catch {
                searchResults = []
            }
            isSearching = false
        }
    }
}

struct FavoriteBookChip: View {
    let book: Book
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                BookCoverImage(url: book.coverImageURL, size: CGSize(width: 60, height: 90))

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.black.opacity(0.6)))
                }
                .offset(x: 4, y: -4)
            }

            Text(book.title)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 60)
        }
    }
}
