import SwiftUI

struct SpoilerText: View {
    let text: String
    let hasSpoilers: Bool
    @State private var isRevealed = false

    var body: some View {
        if hasSpoilers && !isRevealed {
            VStack(spacing: ShelfSpacing.sm) {
                Label("Contains spoilers", systemImage: "eye.slash")
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textSecondary)

                Button("Tap to reveal") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRevealed = true
                    }
                }
                .font(ShelfFonts.subheadlineBold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(ShelfColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.medium))
            .accessibilityHint("Double tap to reveal spoiler content")
        } else {
            Text(text)
                .font(ShelfFonts.bodySerif)
                .foregroundStyle(ShelfColors.textPrimary)
        }
    }
}
