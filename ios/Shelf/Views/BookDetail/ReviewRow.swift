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
                        StarRatingDisplay(rating: review.rating, size: 10)
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
