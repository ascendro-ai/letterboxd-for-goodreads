import SwiftUI

// MARK: - Shelf Row View

struct ShelfRowView: View {
    let title: String
    let icon: String
    let books: [UserBook]
    var accentColor: Color = ShelfColors.accent
    var showHeader: Bool = true
    var onSeeAll: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: showHeader ? ShelfSpacing.sm : 0) {
            if showHeader {
                // Section header
                HStack(alignment: .firstTextBaseline) {
                    Text("\(icon) \(title)")
                        .font(ShelfFonts.headlineSerif)
                        .foregroundStyle(ShelfColors.textPrimary)

                    Spacer()

                    if let onSeeAll {
                        Button(action: onSeeAll) {
                            Text("Edit")
                                .font(ShelfFonts.subheadlineSans)
                                .foregroundStyle(ShelfColors.accent)
                        }
                    }
                }
                .padding(.horizontal, ShelfSpacing.page)
            }

            // Bookshelf container
            BookshelfContainer {
                if books.isEmpty {
                    emptyShelfContent
                } else {
                    populatedShelfContent
                }
            }
        }
    }

    // MARK: - Populated shelf

    private var populatedShelfContent: some View {
        let rows = stride(from: 0, to: books.count, by: 3).map { i in
            Array(books[i..<min(i + 3, books.count)])
        }

        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                WoodenShelf {
                    ForEach(Array(row.enumerated()), id: \.element.id) { bookIdx, userBook in
                        if let book = userBook.book {
                            NavigationLink(value: book) {
                                StylizedBookCard(
                                    title: book.title,
                                    author: book.authors.first?.name,
                                    colorIndex: rowIdx * 3 + bookIdx
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    AddBookSlot()
                }
            }

            // Extra empty shelf if all books fit on one row
            if books.count <= 3 {
                WoodenShelf {
                    AddBookSlot()
                }
            }
        }
    }

    // MARK: - Empty shelf

    private var emptyShelfContent: some View {
        WoodenShelf {
            AddBookSlot()
        }
    }
}

// MARK: - Stylized Book Card

struct StylizedBookCard: View {
    let title: String
    let author: String?
    let colorIndex: Int

    private static let palettes: [(top: Color, bottom: Color, accent: Color)] = [
        // Leather brown
        (Color(red: 0.545, green: 0.271, blue: 0.075),
         Color(red: 0.627, green: 0.322, blue: 0.110),
         Color(red: 0.957, green: 0.894, blue: 0.757)),
        // Dark teal
        (Color(red: 0.102, green: 0.165, blue: 0.227),
         Color(red: 0.184, green: 0.310, blue: 0.310),
         Color(red: 0.784, green: 0.867, blue: 0.816)),
        // Deep navy
        (Color(red: 0.039, green: 0.039, blue: 0.118),
         Color(red: 0.102, green: 0.102, blue: 0.235),
         Color(red: 0.557, green: 0.792, blue: 0.902)),
        // Plum
        (Color(red: 0.165, green: 0.039, blue: 0.165),
         Color(red: 0.290, green: 0.098, blue: 0.259),
         Color(red: 0.910, green: 0.769, blue: 0.910)),
        // Warm leather
        (Color(red: 0.235, green: 0.165, blue: 0.102),
         Color(red: 0.361, green: 0.251, blue: 0.200),
         Color(red: 0.941, green: 0.863, blue: 0.784)),
        // Steel blue
        (Color(red: 0.000, green: 0.102, blue: 0.227),
         Color(red: 0.051, green: 0.231, blue: 0.400),
         Color(red: 0.722, green: 0.847, blue: 0.973)),
        // Gold
        (Color(red: 0.541, green: 0.400, blue: 0.000),
         Color(red: 0.722, green: 0.525, blue: 0.043),
         Color(red: 0.102, green: 0.102, blue: 0.102)),
        // Olive
        (Color(red: 0.102, green: 0.188, blue: 0.063),
         Color(red: 0.182, green: 0.290, blue: 0.118),
         Color(red: 0.831, green: 0.910, blue: 0.722)),
    ]

    private var palette: (top: Color, bottom: Color, accent: Color) {
        Self.palettes[colorIndex % Self.palettes.count]
    }

    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [palette.top, palette.bottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Spine edge (left dark strip)
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.black.opacity(0.3), .black.opacity(0.05)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 6)
                Spacer()
            }

            // Top light reflection
            VStack {
                LinearGradient(
                    colors: [.white.opacity(0.12), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 60)
                Spacer()
            }

            // Decorative lines + text
            VStack(spacing: 0) {
                // Top line
                decorativeLine
                    .padding(.top, 18)

                Spacer()

                // Title
                Text(title)
                    .font(.system(
                        size: title.count > 20 ? 12 : 14,
                        weight: .bold,
                        design: .serif
                    ))
                    .foregroundStyle(palette.accent)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 1)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 14)

                // Author
                if let author {
                    Text(author.uppercased())
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(palette.accent.opacity(0.67))
                        .tracking(1.5)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }

                Spacer()

                // Bottom line
                decorativeLine
                    .padding(.bottom, 28)
            }

            // Corner flourishes
            cornerBrackets
        }
        .frame(width: 105, height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .pressable()
        .accessibilityLabel("\(title)\(author.map { ", by \($0)" } ?? "")")
    }

    private var decorativeLine: some View {
        Rectangle()
            .fill(palette.accent.opacity(0.2))
            .frame(width: 55, height: 1)
    }

    private var cornerBrackets: some View {
        ZStack {
            // Top-right
            VStack {
                HStack {
                    Spacer()
                    CornerBracket()
                        .stroke(palette.accent.opacity(0.27), lineWidth: 1)
                        .frame(width: 6, height: 6)
                        .padding(.trailing, 10)
                        .padding(.top, 8)
                }
                Spacer()
            }
            // Bottom-left
            VStack {
                Spacer()
                HStack {
                    CornerBracket()
                        .rotation(.degrees(180))
                        .stroke(palette.accent.opacity(0.27), lineWidth: 1)
                        .frame(width: 6, height: 6)
                        .padding(.leading, 10)
                        .padding(.bottom, 16)
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Corner Bracket Shape

struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

// MARK: - Add Book Slot

struct AddBookSlot: View {
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(ShelfColors.textTertiary.opacity(0.3))
        }
        .frame(width: 105, height: 148)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    ShelfColors.textTertiary.opacity(0.1),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                )
        )
    }
}

// MARK: - Bookshelf Container

/// Subtle warm background wrapping all shelf rows.
struct BookshelfContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.vertical, ShelfSpacing.md)
        .padding(.horizontal, ShelfSpacing.md)
    }
}

// MARK: - Wooden Shelf

/// Shelf plank with wood grain texture, front lip, and wall-mount bracket supports.
struct WoodenShelf<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    private var plankGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.30, green: 0.24, blue: 0.18),
               Color(red: 0.25, green: 0.20, blue: 0.14),
               Color(red: 0.22, green: 0.17, blue: 0.12)]
            : [Color(red: 0.784, green: 0.600, blue: 0.416),
               Color(red: 0.690, green: 0.494, blue: 0.310),
               Color(red: 0.604, green: 0.427, blue: 0.251)]
    }

    private var lipGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.20, green: 0.15, blue: 0.10),
               Color(red: 0.17, green: 0.13, blue: 0.08)]
            : [Color(red: 0.541, green: 0.384, blue: 0.204),
               Color(red: 0.478, green: 0.333, blue: 0.188)]
    }

    private var bracketGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.22, green: 0.16, blue: 0.10),
               Color(red: 0.18, green: 0.13, blue: 0.08)]
            : [Color(red: 0.541, green: 0.384, blue: 0.204),
               Color(red: 0.478, green: 0.333, blue: 0.188),
               Color(red: 0.416, green: 0.282, blue: 0.157)]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Books row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    content()
                }
                .padding(.horizontal, ShelfSpacing.lg)
                .padding(.bottom, 4)
            }
            .frame(minHeight: 155)

            // Shelf plank with brackets
            ZStack(alignment: .bottom) {
                // Plank
                VStack(spacing: 0) {
                    // Main plank surface with wood grain
                    ZStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: plankGradient,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Inset highlight on top
                        VStack {
                            Rectangle()
                                .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.2))
                                .frame(height: 1)
                            Spacer()
                        }

                        // Wood grain texture
                        WoodGrainTexture()
                            .opacity(colorScheme == .dark ? 0.1 : 0.06)
                    }
                    .frame(height: 12)

                    // Front lip
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(
                            LinearGradient(
                                colors: lipGradient,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 4)
                        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, 4)

                // Wall-mount brackets
                HStack {
                    ShelfBracket(colors: bracketGradient)
                        .padding(.leading, 16)
                    Spacer()
                    ShelfBracket(colors: bracketGradient)
                        .padding(.trailing, 16)
                }
            }
            .padding(.bottom, ShelfSpacing.sm)
        }
    }
}

// MARK: - Wood Grain Texture

struct WoodGrainTexture: View {
    var body: some View {
        Canvas { context, size in
            // Draw subtle vertical grain lines
            var x: CGFloat = 0
            while x < size.width {
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(path, with: .color(.brown), lineWidth: 0.5)
                x += CGFloat.random(in: 8...16)
            }
        }
    }
}

// MARK: - Shelf Bracket

/// Rectangular wall-mount bracket that extends below the shelf plank.
struct ShelfBracket: View {
    let colors: [Color]

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 8, height: 20)
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .offset(y: 6)
    }
}

// MARK: - Shelf Row for Custom Shelves

struct CustomShelfRowView: View {
    let shelf: Shelf
    let books: [UserBook]

    var body: some View {
        ShelfRowView(
            title: shelf.name,
            icon: shelf.isPublic ? "📚" : "🔒",
            books: books,
            accentColor: ShelfColors.accent
        )
    }
}
