import SwiftUI

/// The "Log" tab — quick-add flow: search for a book, then rate/review it.
struct LogView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedBook: Book?

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.hasSearched && viewModel.results.isEmpty {
                VStack(spacing: ShelfSpacing.lg) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(ShelfColors.textTertiary)

                    Text("Log a Book")
                        .font(ShelfFonts.headlineSans)
                        .foregroundStyle(ShelfColors.textPrimary)

                    Text("Search for a book to rate, review, or add to your shelf.")
                        .font(ShelfFonts.subheadlineSans)
                        .foregroundStyle(ShelfColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isSearching && viewModel.results.isEmpty {
                LoadingStateView(message: "Searching...")
            } else if viewModel.hasSearched && viewModel.results.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
            } else {
                List(viewModel.results) { book in
                    Button {
                        selectedBook = book
                    } label: {
                        BookCard(book: book, size: .medium)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(ShelfColors.background)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .shelfPageBackground()
        .navigationTitle("Log")
        .searchable(text: $viewModel.query, prompt: "Search for a book...")
        .onChange(of: viewModel.query) {
            viewModel.search()
        }
        .sheet(item: $selectedBook) { book in
            LogBookSheet(book: book, existingUserBook: nil) { request in
                Task {
                    _ = try? await UserBookService.shared.logBook(request)
                }
                selectedBook = nil
            }
        }
    }
}
