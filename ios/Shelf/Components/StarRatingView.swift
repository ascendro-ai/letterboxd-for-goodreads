import SwiftUI

// MARK: - Interactive Star Rating Input

struct StarRatingView: View {
    @Binding var rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 32
    var spacing: CGFloat = 4
    var color: Color = Color.starGold

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { star in
                starImage(for: star)
                    .font(.system(size: size))
                    .foregroundStyle(color)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleTap(star: star)
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(value: value)
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating: \(formattedRating) out of \(maxRating) stars")
        .accessibilityValue(formattedRating)
        .accessibilityHint("Swipe up or down to adjust rating by half a star")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(Double(maxRating), rating + 0.5)
            case .decrement:
                rating = max(0.5, rating - 0.5)
            @unknown default:
                break
            }
        }
    }

    private func starImage(for star: Int) -> Image {
        let value = Double(star)
        if rating >= value {
            return Image(systemName: "star.fill")
        } else if rating >= value - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    private func handleTap(star: Int) {
        let value = Double(star)
        // Tap same star toggles between full and half
        if rating == value {
            rating = value - 0.5
        } else if rating == value - 0.5 {
            rating = 0
        } else {
            rating = value
        }
    }

    private func handleDrag(value: DragGesture.Value) {
        let totalWidth = CGFloat(maxRating) * (size + spacing)
        let x = max(0, min(value.location.x, totalWidth))
        let starWidth = size + spacing
        let rawRating = x / starWidth
        // Snap to half-star increments
        let snapped = (rawRating * 2).rounded() / 2
        rating = max(0.5, min(Double(maxRating), snapped))
    }

    private var formattedRating: String {
        if rating == 0 { return "0" }
        return rating.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rating)
            : String(format: "%.1f", rating)
    }
}

// MARK: - Display-only Star Rating

struct StarRatingDisplay: View {
    let rating: Double
    var maxRating: Int = 5
    var size: CGFloat = 14
    var spacing: CGFloat = 1
    var color: Color = Color.starGold

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxRating, id: \.self) { star in
                starImage(for: star)
                    .font(.system(size: size))
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rated \(formattedRating) out of \(maxRating) stars")
    }

    private func starImage(for star: Int) -> Image {
        let value = Double(star)
        if rating >= value {
            return Image(systemName: "star.fill")
        } else if rating >= value - 0.5 {
            return Image(systemName: "star.leadinghalf.filled")
        } else {
            return Image(systemName: "star")
        }
    }

    private var formattedRating: String {
        rating.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rating)
            : String(format: "%.1f", rating)
    }
}
