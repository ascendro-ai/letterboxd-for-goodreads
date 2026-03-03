import SwiftUI

struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            HStack(spacing: 10) {
                UserAvatarView(url: review.user.avatarURL, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.user.username)
                        .font(ShelfFonts.subheadlineBold)
                        .foregroundStyle(ShelfColors.textPrimary)

                    HStack(spacing: ShelfSpacing.xxs) {
                        if let rating = review.rating {
                            StarRatingDisplay(rating: rating, size: 10)
                        }
                        Text(review.createdAt.feedTimestamp)
                            .font(ShelfFonts.caption2)
                            .foregroundStyle(ShelfColors.textTertiary)
                    }
                }

                Spacer()
            }

            if let text = review.reviewText, !text.isEmpty {
                SpoilerText(text: text, hasSpoilers: review.hasSpoilers)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, ShelfSpacing.sm)
    }
}

/// Review row that works with UserBook data from the backend reviews endpoint.
/// The backend returns UserBook objects (without user info) for book reviews.
struct UserBookReviewRow: View {
    let userBook: UserBook

    var body: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            HStack(spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ShelfColors.textTertiary)

                VStack(alignment: .leading, spacing: 2) {
                    if let rating = userBook.rating {
                        HStack(spacing: ShelfSpacing.xxs) {
                            StarRatingDisplay(rating: rating, size: 10)
                            Text(userBook.createdAt.feedTimestamp)
                                .font(ShelfFonts.caption2)
                                .foregroundStyle(ShelfColors.textTertiary)
                        }
                    } else {
                        Text(userBook.createdAt.feedTimestamp)
                            .font(ShelfFonts.caption2)
                            .foregroundStyle(ShelfColors.textTertiary)
                    }
                }

                Spacer()
            }

            if let text = userBook.reviewText, !text.isEmpty {
                SpoilerText(text: text, hasSpoilers: userBook.hasSpoilers)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, ShelfSpacing.sm)
    }
}
