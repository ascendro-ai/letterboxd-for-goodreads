import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var showScanner = false

    var body: some View {
        List {
            if viewModel.isSearching && viewModel.results.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if viewModel.hasSearched && viewModel.results.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
            } else {
                ForEach(viewModel.results) { book in
                    NavigationLink(value: book) {
                        BookCard(book: book, size: .medium)
                    }
                }
            }
        }
        .listStyle(.plain)
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
                }
            }
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerView { isbn in
                showScanner = false
                viewModel.query = isbn
                viewModel.search()
            }
        }
    }
}
