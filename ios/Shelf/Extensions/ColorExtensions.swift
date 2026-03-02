/// Semantic color definitions for consistent theming across light and dark modes.

import SwiftUI

extension Color {
    // MARK: - Backgrounds

    /// Primary app background. Near-white in light, deep charcoal in dark.
    static let shelfBackground = Color("ShelfBackground")

    /// Elevated surface (cards, sheets). White in light, slightly lighter charcoal in dark.
    static let cardBackground = Color("CardBackground")

    /// Grouped/inset background for sections.
    static let groupedBackground = Color("GroupedBackground")

    // MARK: - Text

    /// Primary text color with full contrast.
    static let textPrimary = Color("TextPrimary")

    /// Secondary text for subtitles and metadata.
    static let textSecondary = Color("TextSecondary")

    // MARK: - UI Elements

    /// Subtle dividers and separators.
    static let shelfDivider = Color("ShelfDivider")

    /// Star rating gold — consistent across themes.
    static let starGold = Color("StarGold")

    /// Subtle overlay for cover image placeholders.
    static let coverPlaceholder = Color("CoverPlaceholder")
}
