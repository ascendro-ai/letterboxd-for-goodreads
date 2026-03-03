import SwiftUI

/// Animated progress bar for "currently reading" books.
/// Compact (6pt) for feed items, regular (10pt) for detail views.
struct ReadingProgressBar: View {
    let currentPage: Int
    let totalPages: Int
    var isCompact: Bool = false

    private var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1.0, Double(currentPage) / Double(totalPages))
    }

    private var height: CGFloat {
        isCompact ? 6 : 10
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: ShelfSpacing.xxs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(ShelfColors.backgroundTertiary)
                        .frame(height: height)

                    // Fill
                    Capsule()
                        .fill(ShelfColors.accent)
                        .frame(width: geometry.size.width * progress, height: height)
                        .animation(.easeInOut(duration: 0.4), value: progress)
                }
            }
            .frame(height: height)

            if !isCompact {
                Text("\(currentPage) of \(totalPages) pages")
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.textTertiary)
                    .contentTransition(.numericText())
            }
        }
        .accessibilityLabel("Reading progress: \(Int(progress * 100)) percent, page \(currentPage) of \(totalPages)")
    }
}
