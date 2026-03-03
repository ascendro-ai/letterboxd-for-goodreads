import SwiftUI

// MARK: - Colors

/// Central color tokens referencing asset catalog color sets with light/dark variants.
enum ShelfColors {
    static let background = Color("ShelfBackground")
    static let backgroundSecondary = Color("ShelfBackgroundSecondary")
    static let backgroundTertiary = Color("ShelfBackgroundTertiary")
    static let surface = Color("ShelfSurface")
    static let surfaceElevated = Color("ShelfSurfaceElevated")

    static let textPrimary = Color("ShelfTextPrimary")
    static let textSecondary = Color("ShelfTextSecondary")
    static let textTertiary = Color("ShelfTextTertiary")

    static let accent = Color("ShelfAccent")
    static let accentSubtle = Color("ShelfAccentSubtle")

    static let forest = Color("ShelfForest")
    static let amber = Color("ShelfAmber")
    static let ocean = Color("ShelfOcean")
    static let plum = Color("ShelfPlum")

    static let starFilled = Color("ShelfStarFilled")
    static let divider = Color("ShelfDivider")
    static let error = Color("ShelfError")
}

// MARK: - Typography

/// Serif (New York) for literary content, Sans (San Francisco) for UI chrome,
/// Rounded for numeric data displays.
enum ShelfFonts {
    // MARK: Serif — book titles, descriptions, reviews, bios, onboarding headlines

    /// 34pt serif bold — app title, onboarding splash
    static let displayLarge = Font.system(size: 34, weight: .bold, design: .serif)
    /// 28pt serif bold — section hero headings
    static let displayMedium = Font.system(size: 28, weight: .bold, design: .serif)
    /// 24pt serif bold — book title on detail page
    static let displaySmall = Font.system(size: 24, weight: .bold, design: .serif)
    /// 20pt serif semibold — card/section headers
    static let headlineSerif = Font.system(size: 20, weight: .semibold, design: .serif)
    /// 16pt serif regular — book descriptions, reviews, bios
    static let bodySerif = Font.system(size: 16, weight: .regular, design: .serif)
    /// 16pt serif semibold
    static let bodySerifBold = Font.system(size: 16, weight: .semibold, design: .serif)
    /// 13pt serif regular — author names, metadata
    static let captionSerif = Font.system(size: 13, weight: .regular, design: .serif)

    // MARK: Sans — navigation, buttons, labels, metadata, section headers

    /// 20pt sans semibold — navigation titles, section headers
    static let headlineSans = Font.system(size: 20, weight: .semibold)
    /// 15pt sans regular — secondary headings, subtitles
    static let subheadlineSans = Font.system(size: 15, weight: .regular)
    /// 15pt sans semibold — emphasized subtitles, usernames
    static let subheadlineBold = Font.system(size: 15, weight: .semibold)
    /// 16pt sans regular — body text for UI elements
    static let bodySans = Font.system(size: 16, weight: .regular)
    /// 16pt sans semibold — button labels, emphasis
    static let bodySansBold = Font.system(size: 16, weight: .semibold)
    /// 12pt sans regular — timestamps, hints, labels
    static let caption = Font.system(size: 12, weight: .regular)
    /// 12pt sans semibold — badges, counts
    static let captionBold = Font.system(size: 12, weight: .semibold)
    /// 11pt sans regular — fine print
    static let caption2 = Font.system(size: 11, weight: .regular)

    // MARK: Rounded — stats, numeric displays

    /// 28pt rounded bold — large stat numbers
    static let dataLarge = Font.system(size: 28, weight: .bold, design: .rounded)
    /// 20pt rounded semibold — medium stat numbers
    static let dataMedium = Font.system(size: 20, weight: .semibold, design: .rounded)
    /// 14pt rounded semibold — small stat numbers, profile counts
    static let dataSmall = Font.system(size: 14, weight: .semibold, design: .rounded)
}

// MARK: - Spacing

enum ShelfSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    static let page: CGFloat = 20
}

// MARK: - Corner Radius

enum ShelfRadius {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let xl: CGFloat = 16
    static let full: CGFloat = 999
}

// MARK: - Shadows

enum ShelfShadow {
    struct Config {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let coverShadow = Config(
        color: .black.opacity(0.12),
        radius: 4,
        x: 0,
        y: 2
    )

    static let heroCoverShadow = Config(
        color: .black.opacity(0.2),
        radius: 12,
        x: 0,
        y: 6
    )

    static let cardShadow = Config(
        color: .black.opacity(0.06),
        radius: 8,
        x: 0,
        y: 2
    )

    static let elevatedShadow = Config(
        color: .black.opacity(0.1),
        radius: 16,
        x: 0,
        y: 4
    )
}
