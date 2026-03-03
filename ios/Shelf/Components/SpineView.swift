import SwiftUI

/// Digital bookshelf showing book spines as narrow colored rectangles
/// with 90-degree rotated titles. A third display mode for Profile view.
struct SpineView: View {
    let books: [UserBook]

    private static let spineColors: [Color] = [
        Color(red: 0.45, green: 0.28, blue: 0.18), // leather brown
        Color(red: 0.15, green: 0.20, blue: 0.35), // navy
        Color(red: 0.55, green: 0.15, blue: 0.18), // burgundy
        Color(red: 0.30, green: 0.38, blue: 0.22), // olive
        Color(red: 0.88, green: 0.84, blue: 0.76), // cream
        Color(red: 0.35, green: 0.25, blue: 0.40), // plum
        Color(red: 0.22, green: 0.35, blue: 0.32), // teal
        Color(red: 0.50, green: 0.20, blue: 0.15), // rust
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(books.enumerated()), id: \.element.id) { index, userBook in
                        spineItem(for: userBook, index: index)
                    }
                }
                .padding(.horizontal, ShelfSpacing.lg)
            }

            // Shelf bracket line
            Rectangle()
                .fill(ShelfColors.divider)
                .frame(height: 2)
                .padding(.horizontal, ShelfSpacing.lg)
        }
    }

    private func spineItem(for userBook: UserBook, index: Int) -> some View {
        let spineWidth: CGFloat = CGFloat.random(in: 28...36)
        let spineHeight: CGFloat = spineHeightForBook(userBook)
        let color = Self.spineColors[index % Self.spineColors.count]
        let textColor: Color = color.isLight ? ShelfColors.textPrimary : .white

        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: spineWidth, height: spineHeight)
            .overlay {
                Text(userBook.book?.title ?? "")
                    .font(.system(size: 8, weight: .medium, design: .serif))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .rotationEffect(.degrees(-90))
                    .frame(width: spineHeight - 8, height: spineWidth - 4)
                    .clipped()
            }
            .accessibilityLabel(userBook.book?.title ?? "Book spine")
    }

    private func spineHeightForBook(_ userBook: UserBook) -> CGFloat {
        // Vary height using a hash of the book title for consistent pseudo-random sizing
        let hash = abs(userBook.book?.title.hashValue ?? userBook.id.hashValue)
        let normalized = CGFloat(hash % 80)
        return 80 + normalized // range: 80-160pt
    }
}

// MARK: - Color Light/Dark Detection

private extension Color {
    var isLight: Bool {
        // Approximate luminance check for choosing text color
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6
    }
}
