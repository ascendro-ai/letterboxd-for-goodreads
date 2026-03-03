import SwiftUI

/// Prompt card shown when the feed falls back to popular/mixed content,
/// encouraging new users to follow people they know.
struct DiscoverPromptCard: View {
    var onFindPeople: (() -> Void)?

    var body: some View {
        VStack(spacing: ShelfSpacing.md) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 28))
                .foregroundStyle(ShelfColors.accent)

            Text("Find people you know")
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Follow readers to fill your feed with books they're reading and reviewing.")
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)

            if let onFindPeople {
                Button(action: onFindPeople) {
                    Text("Find People")
                        .shelfPrimaryButton()
                }
            }
        }
        .padding(ShelfSpacing.xl)
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.xl))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
