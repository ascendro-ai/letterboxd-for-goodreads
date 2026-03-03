import SwiftUI

struct BookCard: View {
    let book: Book
    var showRating: Bool = true
    var size: BookCardSize = .medium

    var body: some View {
        HStack(spacing: 12) {
            BookCoverImage(url: book.coverImageURL, size: size.coverSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(size.titleFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                if let authorName = book.authors.first?.name {
                    Text(authorName)
                        .font(size.subtitleFont)
                        .foregroundStyle(ShelfColors.textSecondary)
                        .lineLimit(1)
                }

                if showRating, let rating = book.averageRating {
                    HStack(spacing: ShelfSpacing.xxs) {
                        StarRatingDisplay(rating: rating, size: size.starSize)
                        Text(String(format: "%.1f", rating))
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textSecondary)
                        if let count = book.ratingsCount, count > 0 {
                            Text("(\(count.formatted()))")
                                .font(ShelfFonts.caption2)
                                .foregroundStyle(ShelfColors.textTertiary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .pressable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = [book.title]
        if let author = book.authors.first?.name { parts.append("by \(author)") }
        if showRating, let rating = book.averageRating {
            parts.append("rated \(String(format: "%.1f", rating)) out of 5")
        }
        return parts.joined(separator: ", ")
    }
}

enum BookCardSize {
    case small, medium, large

    var coverSize: CGSize {
        switch self {
        case .small: CGSize(width: 40, height: 60)
        case .medium: CGSize(width: 60, height: 90)
        case .large: CGSize(width: 80, height: 120)
        }
    }

    var titleFont: Font {
        switch self {
        case .small: ShelfFonts.subheadlineBold
        case .medium: ShelfFonts.headlineSerif
        case .large: ShelfFonts.displaySmall
        }
    }

    var subtitleFont: Font {
        switch self {
        case .small: ShelfFonts.caption
        case .medium: ShelfFonts.captionSerif
        case .large: ShelfFonts.bodySerif
        }
    }

    var starSize: CGFloat {
        switch self {
        case .small: 10
        case .medium: 12
        case .large: 14
        }
    }
}
