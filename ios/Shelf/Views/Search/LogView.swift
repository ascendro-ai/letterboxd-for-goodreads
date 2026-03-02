import SwiftUI

/// The "Log" tab — quick-add flow: search for a book, then rate/review it.
struct LogView: View {
    @State private var viewModel = SearchViewModel()
    @State private var selectedBook: Book?

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.hasSearched && viewModel.results.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("Log a Book")
                        .font(.title3.weight(.semibold))

                    Text("Search for a book to rate, review, or add to your shelf.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                }
                .listStyle(.plain)
            }
        }
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
