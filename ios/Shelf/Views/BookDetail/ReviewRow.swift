import SwiftUI

struct ReviewRow: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                UserAvatarView(url: review.user.avatarURL, size: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.user.username)
                        .font(.subheadline.weight(.semibold))

                    HStack(spacing: 4) {
                        if let rating = review.rating {
                            StarRatingDisplay(rating: rating, size: 10)
                        }
                        Text(review.createdAt.feedTimestamp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            if let text = review.reviewText, !text.isEmpty {
                SpoilerText(text: text, hasSpoilers: review.hasSpoilers)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Review row that works with UserBook data from the backend reviews endpoint.
/// The backend returns UserBook objects (without user info) for book reviews.
struct UserBookReviewRow: View {
    let userBook: UserBook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    if let rating = userBook.rating {
                        HStack(spacing: 4) {
                            StarRatingDisplay(rating: rating, size: 10)
                            Text(userBook.createdAt.feedTimestamp)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } else {
                        Text(userBook.createdAt.feedTimestamp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            if let text = userBook.reviewText, !text.isEmpty {
                SpoilerText(text: text, hasSpoilers: userBook.hasSpoilers)
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
