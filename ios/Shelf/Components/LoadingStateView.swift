import SwiftUI

// MARK: - Loading State

struct LoadingStateView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: ShelfSpacing.md) {
            ProgressView()
                .tint(ShelfColors.accent)
            Text(message)
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)?
    var actionTitle: String?

    var body: some View {
        VStack(spacing: ShelfSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(ShelfColors.textTertiary)

            Text(title)
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            Text(message)
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ShelfSpacing.xxxl)

            if let action, let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .shelfPrimaryButton()
                }
                .padding(.top, ShelfSpacing.xxs)
                .padding(.horizontal, ShelfSpacing.xxxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Error State

struct ErrorStateView: View {
    let error: Error
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: ShelfSpacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(ShelfColors.amber)

            Text("Something went wrong")
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            Text(error.localizedDescription)
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ShelfSpacing.xxxl)

            if let retry {
                Button(action: retry) {
                    Text("Try Again")
                        .shelfPrimaryButton()
                }
                .padding(.horizontal, ShelfSpacing.xxxl)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
