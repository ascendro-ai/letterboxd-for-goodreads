import SwiftUI

struct FeedItemView: View {
    let item: FeedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User header
            HStack(spacing: 10) {
                UserAvatarView(url: item.user.avatarURL, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.user.username)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 4) {
                        Text(item.activityType.displayText)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(item.createdAt.feedTimestamp)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            // Book info
            HStack(spacing: 12) {
                BookCoverImage(url: item.book.coverImageURL, size: CGSize(width: 50, height: 75))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.book.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)

                    if let author = item.book.authors.first?.name {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        .padding(.vertical, 12)
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
