import SwiftUI

// MARK: - Card Modifier

struct ShelfCardModifier: ViewModifier {
    var padding: CGFloat = ShelfSpacing.xxl

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ShelfColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
            .shadow(
                color: ShelfShadow.cardShadow.color,
                radius: ShelfShadow.cardShadow.radius,
                x: ShelfShadow.cardShadow.x,
                y: ShelfShadow.cardShadow.y
            )
    }
}

// MARK: - Primary Button Modifier

struct ShelfPrimaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ShelfFonts.bodySansBold)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(ShelfColors.accent)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
    }
}

// MARK: - Secondary Button Modifier

struct ShelfSecondaryButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ShelfFonts.subheadlineBold)
            .padding(.horizontal, ShelfSpacing.lg)
            .padding(.vertical, ShelfSpacing.sm)
            .background(ShelfColors.backgroundTertiary)
            .foregroundStyle(ShelfColors.textPrimary)
            .clipShape(Capsule())
    }
}

// MARK: - Text Field Modifier

struct ShelfTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(ShelfColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.medium))
    }
}

// MARK: - Cover Shadow Modifier

struct CoverShadowModifier: ViewModifier {
    var isHero: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let config = isHero ? ShelfShadow.heroCoverShadow : ShelfShadow.coverShadow
        // Slightly higher shadow opacity in dark mode for cover depth
        let opacity: Double = colorScheme == .dark ? 1.3 : 1.0
        content
            .shadow(
                color: config.color.opacity(opacity),
                radius: config.radius,
                x: config.x,
                y: config.y
            )
    }
}

// MARK: - Page Background Modifier

struct ShelfPageBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ShelfColors.background)
    }
}

// MARK: - Frosted Glass Modifier

struct FrostedGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .overlay(
                ShelfColors.surface.opacity(0.05)
            )
    }
}

// MARK: - View Extensions

extension View {
    func shelfCard(padding: CGFloat = ShelfSpacing.xxl) -> some View {
        modifier(ShelfCardModifier(padding: padding))
    }

    func shelfPrimaryButton() -> some View {
        modifier(ShelfPrimaryButtonModifier())
    }

    func shelfSecondaryButton() -> some View {
        modifier(ShelfSecondaryButtonModifier())
    }

    func shelfTextField() -> some View {
        modifier(ShelfTextFieldModifier())
    }

    func coverShadow(isHero: Bool = false) -> some View {
        modifier(CoverShadowModifier(isHero: isHero))
    }

    func shelfPageBackground() -> some View {
        modifier(ShelfPageBackgroundModifier())
    }

    func frostedGlass() -> some View {
        modifier(FrostedGlassModifier())
    }

    func pressable() -> some View {
        modifier(PressableModifier())
    }

    func springNavigation() -> some View {
        modifier(SpringNavigationModifier())
    }
}

// MARK: - Custom Divider

/// Warm-toned 0.5pt divider replacing system `Divider()`.
struct ShelfDivider: View {
    var body: some View {
        Rectangle()
            .fill(ShelfColors.divider)
            .frame(height: 0.5)
    }
}
