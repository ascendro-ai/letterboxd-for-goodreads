import SwiftUI

struct BookDetailView: View {
    let bookID: UUID
    @State private var viewModel: BookDetailViewModel
    @State private var showLogSheet = false
    @State private var showReport = false

    init(bookID: UUID) {
        self.bookID = bookID
        self._viewModel = State(initialValue: BookDetailViewModel(bookID: bookID))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.book == nil {
                LoadingStateView()
            } else if let error = viewModel.error, viewModel.book == nil {
                ErrorStateView(error: error) {
                    Task { await viewModel.load() }
                }
            } else if let book = viewModel.book {
                bookContent(book)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showReport = true
                    } label: {
                        Label("Report an Issue", systemImage: "flag")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .task {
            if viewModel.book == nil {
                await viewModel.load()
            }
        }
        .sheet(isPresented: $showReport) {
            ReportContentView(target: .book(bookID))
        }
        .sheet(isPresented: $showLogSheet) {
            if let book = viewModel.book {
                LogBookSheet(book: book, existingUserBook: viewModel.userBook) { request in
                    Task {
                        if viewModel.userBook != nil {
                            try? await viewModel.updateBook(request: UpdateBookRequest(
                                status: request.status,
                                rating: request.rating,
                                reviewText: request.reviewText,
                                hasSpoilers: request.hasSpoilers,
                                startedAt: request.startedAt,
                                finishedAt: request.finishedAt
                            ))
                        } else {
                            try? await viewModel.logBook(request: request)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bookContent(_ book: Book) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero cover
                HeroBookCover(url: book.coverImageURL)
                    .padding(.top, 8)

                // Title & Authors
                VStack(spacing: 6) {
                    Text(book.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    if !book.authors.isEmpty {
                        Text(book.authors.map(\.name).joined(separator: ", "))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let year = book.firstPublishedYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal)

                // Rating summary
                if let rating = book.averageRating {
                    HStack(spacing: 8) {
                        StarRatingDisplay(rating: rating, size: 16)
                        Text(String(format: "%.1f", rating))
                            .font(.headline)
                        Text("(\(book.ratingsCount.formatted()) ratings)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Action button
                Button {
                    showLogSheet = true
                } label: {
                    Label(
                        viewModel.userBook != nil ? "Edit Log" : "Log This Book",
                        systemImage: viewModel.userBook != nil ? "pencil" : "plus"
                    )
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Description
                if let description = book.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                // Subjects
                if !book.subjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres")
                            .font(.headline)
                        FlowLayout(spacing: 6) {
                            ForEach(book.subjects.prefix(8), id: \.self) { subject in
                                Text(subject)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                // Bookshop affiliate link
                if let url = book.bookshopURL, let bookshopURL = URL(string: url) {
                    Link(destination: bookshopURL) {
                        Label("Buy on Bookshop.org", systemImage: "cart")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.systemGray5))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)
                }

                // Reviews section
                if !viewModel.reviews.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Reviews")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.reviews) { review in
                            ReviewRow(review: review)
                        }
                    }
                }

                // Similar books
                if !viewModel.similarBooks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Readers also enjoyed")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.similarBooks) { similar in
                                    NavigationLink(value: similar) {
                                        VStack(spacing: 6) {
                                            BookCoverImage(
                                                url: similar.coverImageURL,
                                                size: CGSize(width: 80, height: 120)
                                            )
                                            Text(similar.title)
                                                .font(.caption)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 80)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }
}
