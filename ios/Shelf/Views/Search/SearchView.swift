import SwiftUI

// MARK: - Genre Data

private struct Genre: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
}

private let genres: [Genre] = [
    Genre(name: "Fiction", emoji: "📖"),
    Genre(name: "Non-Fiction", emoji: "🧠"),
    Genre(name: "Sci-Fi", emoji: "🚀"),
    Genre(name: "Philosophy", emoji: "🏛️"),
    Genre(name: "Business", emoji: "📊"),
    Genre(name: "Biography", emoji: "👤"),
    Genre(name: "Poetry", emoji: "🌙"),
    Genre(name: "History", emoji: "⏳"),
]

// MARK: - Popular Author

private struct PopularAuthor: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let gradientColors: (Color, Color)
}

private let popularAuthors: [PopularAuthor] = [
    PopularAuthor(name: "Haruki Murakami", initials: "HM",
                  gradientColors: (Color(red: 0.165, green: 0.227, blue: 0.165), Color(red: 0.290, green: 0.416, blue: 0.290))),
    PopularAuthor(name: "Toni Morrison", initials: "TM",
                  gradientColors: (Color(red: 0.227, green: 0.102, blue: 0.102), Color(red: 0.416, green: 0.227, blue: 0.227))),
    PopularAuthor(name: "Jorge Luis Borges", initials: "JB",
                  gradientColors: (Color(red: 0.102, green: 0.165, blue: 0.290), Color(red: 0.227, green: 0.353, blue: 0.541))),
    PopularAuthor(name: "Ursula K. Le Guin", initials: "UL",
                  gradientColors: (Color(red: 0.165, green: 0.102, blue: 0.227), Color(red: 0.353, green: 0.227, blue: 0.416))),
    PopularAuthor(name: "Cormac McCarthy", initials: "CM",
                  gradientColors: (Color(red: 0.227, green: 0.165, blue: 0.102), Color(red: 0.416, green: 0.353, blue: 0.227))),
]

// MARK: - Search View

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, ShelfSpacing.page)
                    .padding(.top, ShelfSpacing.md)

                if viewModel.hasSearched || viewModel.isSearching {
                    searchResults
                } else {
                    discoverContent
                }
            }
        }
        .shelfPageBackground()
        .navigationTitle("Discover")
        .navigationDestination(for: Book.self) { book in
            BookDetailView(bookID: book.id)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(
                    isSearchFocused ? ShelfColors.accent : ShelfColors.textTertiary
                )

            TextField("Search books, authors, genres...", text: $viewModel.query)
                .font(ShelfFonts.bodySans)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit { viewModel.search() }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(ShelfColors.accent)
                        .frame(width: 24, height: 24)
                        .background(ShelfColors.textTertiary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, ShelfSpacing.lg)
        .frame(height: 48)
        .background(
            isSearchFocused
                ? AnyShapeStyle(ShelfColors.surface.opacity(0.9))
                : AnyShapeStyle(ShelfColors.textTertiary.opacity(0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSearchFocused ? ShelfColors.accent.opacity(0.2) : .clear,
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: isSearchFocused ? ShelfColors.accent.opacity(0.1) : .clear,
            radius: isSearchFocused ? 16 : 0,
            y: isSearchFocused ? 4 : 0
        )
        .animation(.easeInOut(duration: 0.25), value: isSearchFocused)
        .onChange(of: viewModel.query) {
            viewModel.search()
        }
    }

    // MARK: - Discover Content (default state)

    private var discoverContent: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.xxl) {
            // Browse Genres
            genreChips

            // Trending This Week
            trendingSection

            // Popular Authors
            popularAuthorsSection

            // Reading stat prompt
            readingStatCard
        }
        .padding(.top, ShelfSpacing.xl)
        .padding(.bottom, 120)
    }

    // MARK: - Genre Chips

    private var genreChips: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.md) {
            sectionLabel("Browse Genres")

            FlowLayoutView(spacing: 8) {
                ForEach(genres) { genre in
                    Button {
                        viewModel.query = genre.name
                        viewModel.search()
                    } label: {
                        HStack(spacing: 6) {
                            Text(genre.emoji)
                                .font(.system(size: 15))
                            Text(genre.name)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, ShelfSpacing.lg)
                        .padding(.vertical, 10)
                        .background(ShelfColors.textTertiary.opacity(0.06))
                        .foregroundStyle(ShelfColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, ShelfSpacing.page)
        }
    }

    // MARK: - Trending Section

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.md) {
            HStack {
                sectionLabel("Trending This Week")
                Spacer()
                Text("See All")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ShelfColors.accent)
            }
            .padding(.horizontal, ShelfSpacing.page)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(viewModel.results.prefix(6)) { book in
                        NavigationLink(value: book) {
                            trendingBookCard(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ShelfSpacing.page)
            }
        }
    }

    private func trendingBookCard(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BookCoverImage(
                url: book.coverImageURL,
                size: CGSize(width: 110, height: 156),
                bookTitle: book.title
            )
            .coverShadow()
            .pressable()

            VStack(alignment: .leading, spacing: 1) {
                Text(book.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ShelfColors.textPrimary)
                    .lineLimit(1)

                if let author = book.authors.first?.name {
                    Text(author)
                        .font(.system(size: 11))
                        .foregroundStyle(ShelfColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(width: 110, alignment: .leading)
        }
    }

    // MARK: - Popular Authors

    private var popularAuthorsSection: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.md) {
            sectionLabel("Popular Authors")
                .padding(.horizontal, ShelfSpacing.page)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ShelfSpacing.lg) {
                    ForEach(popularAuthors) { author in
                        Button {
                            viewModel.query = author.name
                            viewModel.search()
                        } label: {
                            VStack(spacing: 8) {
                                // Avatar circle with initials
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [author.gradientColors.0, author.gradientColors.1],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)

                                    Text(author.initials)
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundStyle(.white.opacity(0.85))
                                }

                                Text(author.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(ShelfColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(width: 64)
                            }
                        }
                    }
                }
                .padding(.horizontal, ShelfSpacing.page)
            }
        }
    }

    // MARK: - Reading Stat Card

    private var readingStatCard: some View {
        VStack(spacing: 8) {
            Text("📚")
                .font(.system(size: 28))

            Text("Start discovering")
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Search for books, browse genres,\nor scan a barcode to get started.")
                .font(.system(size: 13))
                .foregroundStyle(ShelfColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(ShelfSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ShelfColors.textTertiary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ShelfColors.textTertiary.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, ShelfSpacing.page)
    }

    // MARK: - Search Results

    private var searchResults: some View {
        VStack(spacing: 0) {
            if viewModel.isSearching && viewModel.results.isEmpty {
                // Shimmer loading placeholders
                ForEach(0..<4, id: \.self) { i in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(ShelfColors.textTertiary.opacity(0.08 + Double(i) * 0.02))
                            .frame(width: 52, height: 74)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ShelfColors.textTertiary.opacity(0.08))
                                .frame(width: CGFloat(180 - i * 20), height: 14)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ShelfColors.textTertiary.opacity(0.05))
                                .frame(width: CGFloat(120 - i * 15), height: 11)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, ShelfSpacing.page)
                    .padding(.vertical, 14)

                    if i < 3 {
                        ShelfDivider()
                            .padding(.horizontal, ShelfSpacing.page)
                    }
                }
                .redacted(reason: .placeholder)

                Text("Searching for \"\(viewModel.query)\"...")
                    .font(.system(size: 13))
                    .foregroundStyle(ShelfColors.textTertiary)
                    .padding(.top, ShelfSpacing.xxl)
            } else if viewModel.hasSearched && viewModel.results.isEmpty {
                ContentUnavailableView.search(text: viewModel.query)
                    .padding(.top, ShelfSpacing.xxxl)
            } else {
                ForEach(viewModel.results) { book in
                    NavigationLink(value: book) {
                        BookCard(book: book, size: .medium)
                            .padding(.horizontal, ShelfSpacing.page)
                            .padding(.vertical, ShelfSpacing.sm)
                    }
                    .buttonStyle(.plain)

                    ShelfDivider()
                        .padding(.horizontal, ShelfSpacing.page)
                }
            }
        }
        .padding(.top, ShelfSpacing.lg)
        .padding(.bottom, 120)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(ShelfColors.textTertiary)
            .tracking(0.5)
    }
}

// MARK: - Flow Layout (wrapping genre chips)

struct FlowLayoutView<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        _FlowLayout(spacing: spacing) {
            content()
        }
    }
}

private struct _FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
