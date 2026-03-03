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
        .shelfPageBackground()
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
            VStack(spacing: ShelfSpacing.xxl) {
                // Hero cover
                HeroBookCover(url: book.coverImageURL)
                    .padding(.top, ShelfSpacing.sm)

                // Title & Authors
                VStack(spacing: ShelfSpacing.xs) {
                    Text(book.title)
                        .font(ShelfFonts.displaySmall)
                        .foregroundStyle(ShelfColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    if !book.authors.isEmpty {
                        Text(book.authors.map(\.name).joined(separator: ", "))
                            .font(ShelfFonts.captionSerif)
                            .foregroundStyle(ShelfColors.textSecondary)
                    }

                    if let year = book.firstPublishedYear {
                        Text(String(year))
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textTertiary)
                    }
                }
                .padding(.horizontal)

                // Series badge
                if !viewModel.seriesList.isEmpty {
                    VStack(spacing: ShelfSpacing.xxs) {
                        ForEach(viewModel.seriesList) { series in
                            if let work = series.works.first {
                                SeriesBadge(series: series, position: work.position)
                            }
                        }
                    }
                }

                // Rating summary
                if let rating = book.averageRating {
                    HStack(spacing: ShelfSpacing.sm) {
                        StarRatingDisplay(rating: rating, size: 16)
                        Text(String(format: "%.1f", rating))
                            .font(ShelfFonts.headlineSans)
                            .foregroundStyle(ShelfColors.textPrimary)
                        Text("(\((book.ratingsCount ?? 0).formatted()) ratings)")
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textSecondary)
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
                    .shelfPrimaryButton()
                }
                .padding(.horizontal)
                .accessibilityLabel(viewModel.userBook != nil ? "Edit your log for \(book.title)" : "Log \(book.title)")

                // Description
                if let description = book.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
                        Text("About")
                            .font(ShelfFonts.headlineSans)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(description)
                            .font(ShelfFonts.bodySerif)
                            .foregroundStyle(ShelfColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }

                // Content tags
                ContentTagsSection(workID: book.id)

                // Subjects
                if let subjects = book.subjects, !subjects.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
                        Text("Genres")
                            .font(ShelfFonts.headlineSans)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        FlowLayout(spacing: ShelfSpacing.xs) {
                            ForEach(subjects.prefix(8), id: \.self) { subject in
                                Text(subject)
                                    .font(ShelfFonts.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(ShelfColors.backgroundTertiary)
                                    .foregroundStyle(ShelfColors.textSecondary)
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
                            .font(ShelfFonts.subheadlineBold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(ShelfColors.backgroundSecondary)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.medium))
                    }
                    .padding(.horizontal)
                }

                // Reviews section
                if !viewModel.reviews.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.md) {
                        Text("Reviews")
                            .font(ShelfFonts.headlineSans)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal)

                        ForEach(viewModel.reviews) { userBook in
                            UserBookReviewRow(userBook: userBook)
                        }
                    }
                }

                // Similar books
                if !viewModel.similarBooks.isEmpty {
                    VStack(alignment: .leading, spacing: ShelfSpacing.md) {
                        Text("Readers also enjoyed")
                            .font(ShelfFonts.headlineSerif)
                            .foregroundStyle(ShelfColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ShelfSpacing.md) {
                                ForEach(viewModel.similarBooks) { similar in
                                    NavigationLink(value: similar) {
                                        VStack(spacing: ShelfSpacing.xs) {
                                            BookCoverImage(
                                                url: similar.coverImageURL,
                                                size: CGSize(width: 80, height: 120)
                                            )
                                            Text(similar.title)
                                                .font(ShelfFonts.caption)
                                                .foregroundStyle(ShelfColors.textSecondary)
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
            .padding(.bottom, ShelfSpacing.xxl)
        }
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }
}
