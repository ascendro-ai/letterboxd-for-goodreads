import SwiftUI

struct FeedItemView: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.md) {
            // User header
            HStack(spacing: 10) {
                UserAvatarView(url: item.user.avatarURL, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.user.username)
                        .font(ShelfFonts.subheadlineBold)
                        .foregroundStyle(ShelfColors.textPrimary)

                    HStack(spacing: ShelfSpacing.xxs) {
                        Text(item.activityType.displayText)
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textSecondary)

                        Text(item.createdAt.feedTimestamp)
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textTertiary)
                    }
                }

                Spacer()
            }

            // Book info
            HStack(spacing: ShelfSpacing.md) {
                BookCoverImage(url: item.book.coverImageURL, size: CGSize(width: 50, height: 75))

                VStack(alignment: .leading, spacing: ShelfSpacing.xxs) {
                    Text(item.book.title)
                        .font(ShelfFonts.subheadlineBold)
                        .foregroundStyle(ShelfColors.textPrimary)
                        .lineLimit(2)

                    if let author = item.book.authors.first?.name {
                        Text(author)
                            .font(ShelfFonts.captionSerif)
                            .foregroundStyle(ShelfColors.textSecondary)
                    }

                    if let rating = item.rating {
                        StarRatingDisplay(rating: rating, size: 12)
                    }
                }
            }

            // Review text
            if let reviewText = item.reviewText, !reviewText.isEmpty {
                SpoilerText(text: reviewText, hasSpoilers: item.hasSpoilers)
                    .lineLimit(4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, ShelfSpacing.md)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var parts = ["\(item.user.username) \(item.activityType.displayText) \(item.book.title)"]
        if let author = item.book.authors.first?.name { parts.append("by \(author)") }
        if let rating = item.rating { parts.append("rated \(String(format: "%.1f", rating)) stars") }
        return parts.joined(separator: ", ")
    }
}
