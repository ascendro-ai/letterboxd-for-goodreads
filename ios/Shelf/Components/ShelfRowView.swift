import SwiftUI

struct ShelfRowView: View {
    let title: String
    let books: [UserBook]
    var accentColor: Color = ShelfColors.accent
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.md) {
            // Section header
            HStack {
                Text(title)
                    .font(ShelfFonts.headlineSans)
                    .foregroundStyle(ShelfColors.textPrimary)

                Spacer()

                if let onSeeAll, !books.isEmpty {
                    Button(action: onSeeAll) {
                        Text("See all")
                            .font(ShelfFonts.caption)
                            .foregroundStyle(accentColor)
                    }
                }
            }
            .padding(.horizontal, ShelfSpacing.page)

            if books.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ShelfSpacing.md) {
                        ForEach(books) { userBook in
                            if let book = userBook.book {
                                NavigationLink(value: book) {
                                    coverItem(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, ShelfSpacing.page)
                }
            }
        }
    }

    @ViewBuilder
    private func coverItem(book: Book) -> some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.xs) {
            BookCoverImage(
                url: book.coverImageURL,
                size: CGSize(width: 110, height: 165),
                bookTitle: book.title
            )
            .coverShadow()
            .pressable()

            Text(book.title)
                .font(ShelfFonts.caption)
                .foregroundStyle(ShelfColors.textPrimary)
                .lineLimit(1)
                .frame(width: 110, alignment: .leading)

            if let author = book.authors.first?.name {
                Text(author)
                    .font(ShelfFonts.caption2)
                    .foregroundStyle(ShelfColors.textTertiary)
                    .lineLimit(1)
                    .frame(width: 110, alignment: .leading)
            }
        }
    }

    private var emptyState: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ShelfSpacing.md) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: ShelfRadius.cover)
                        .strokeBorder(
                            ShelfColors.textTertiary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                        .frame(width: 110, height: 165)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(ShelfColors.textTertiary.opacity(0.5))
                        }
                }
            }
            .padding(.horizontal, ShelfSpacing.page)
        }
    }
}

// MARK: - Shelf Row for Custom Shelves

struct CustomShelfRowView: View {
    let shelf: Shelf
    let books: [UserBook]

    var body: some View {
        ShelfRowView(
            title: shelf.name,
            books: books,
            accentColor: ShelfColors.accent
        )
    }
}
