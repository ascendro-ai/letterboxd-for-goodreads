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
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if showRating, let rating = book.averageRating {
                    HStack(spacing: 4) {
                        StarRatingDisplay(rating: rating, size: size.starSize)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if book.ratingsCount > 0 {
                            Text("(\(book.ratingsCount.formatted()))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title) by \(book.authors.first?.name ?? "Unknown author")")
        .accessibilityValue(book.averageRating.map { "Rated \(String(format: "%.1f", $0)) stars" } ?? "")
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
        case .small: .subheadline
        case .medium: .headline
        case .large: .title3
        }
    }

    var subtitleFont: Font {
        switch self {
        case .small: .caption
        case .medium: .subheadline
        case .large: .body
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
