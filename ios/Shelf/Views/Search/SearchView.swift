import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var showScanner = false
    @State private var scannedBookID: UUID?

    var body: some View {
        List {
            if viewModel.isSearching && viewModel.results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(ShelfColors.accent)
                    Spacer()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(ShelfColors.background)
            } else if viewModel.hasSearched && viewModel.results.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
                    .listRowBackground(ShelfColors.background)
            } else {
                ForEach(viewModel.results) { book in
                    NavigationLink(value: book) {
                        BookCard(book: book, size: .medium)
                    }
                    .listRowBackground(ShelfColors.background)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .shelfPageBackground()
        .searchable(text: $viewModel.query, prompt: "Search books, authors...")
        .onChange(of: viewModel.query) {
            viewModel.search()
        }
        .navigationTitle("Search")
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(ShelfColors.accent)
                }
                .accessibilityLabel("Scan barcode")
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView { book in
                showScanner = false
                scannedBookID = book.id
            }
        }
        .navigationDestination(item: $scannedBookID) { bookID in
            BookDetailView(bookID: bookID)
        }
    }
}
