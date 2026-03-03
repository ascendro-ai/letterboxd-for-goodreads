import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    private let subscriptionService = SubscriptionService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ShelfSpacing.xxl) {
                    // Header
                    VStack(spacing: ShelfSpacing.md) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(ShelfColors.starFilled)

                        Text("Shelf Premium")
                            .font(ShelfFonts.displaySmall)

                        Text("Get the most out of your reading life")
                            .font(ShelfFonts.subheadlineSans)
                            .foregroundStyle(ShelfColors.textSecondary)
                    }
                    .padding(.top, ShelfSpacing.xl)

                    // Features
                    VStack(alignment: .leading, spacing: ShelfSpacing.lg) {
                        PremiumFeatureRow(icon: "eye.slash", title: "Ad-free experience", description: "No ads, ever.")
                        PremiumFeatureRow(icon: "books.vertical", title: "Unlimited shelves", description: "Create as many shelves as you want.")
                        PremiumFeatureRow(icon: "chart.bar", title: "Advanced stats", description: "Deep insights into your reading habits.")
                        PremiumFeatureRow(icon: "paintpalette", title: "Custom themes", description: "Personalize your profile.")
                        PremiumFeatureRow(icon: "calendar", title: "Enhanced Year in Review", description: "Beautiful reading year summary.")
                    }
                    .padding(.horizontal)

                    // Package options
                    if let offering = subscriptionService.currentOffering {
                        VStack(spacing: ShelfSpacing.md) {
                            ForEach(offering.availablePackages, id: \.identifier) { package in
                                PackageOptionView(
                                    package: package,
                                    isSelected: selectedPackage?.identifier == package.identifier
                                ) {
                                    selectedPackage = package
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Fallback display when offerings haven't loaded
                        VStack(spacing: ShelfSpacing.md) {
                            PricingCard(title: "Monthly", price: "$4.99/mo", isPopular: false, isSelected: false)
                            PricingCard(title: "Annual", price: "$39.99/yr", isPopular: true, isSelected: false)
                        }
                        .padding(.horizontal)
                    }

                    // Purchase button
                    Button {
                        purchase()
                    } label: {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Subscribe")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .shelfPrimaryButton()
                    .disabled(isPurchasing || selectedPackage == nil)
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.error)
                    }

                    // Restore
                    Button("Restore Purchases") {
                        restore()
                    }
                    .font(ShelfFonts.subheadlineSans)
                    .foregroundStyle(ShelfColors.textSecondary)

                    // Legal
                    Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the current period ends.")
                        .font(ShelfFonts.caption2)
                        .foregroundStyle(ShelfColors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, ShelfSpacing.xxl)
                        .padding(.bottom, ShelfSpacing.xl)
                }
            }
            .shelfPageBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscriptionService.fetchOfferings()
                AnalyticsService.track(.paywallViewed)
            }
        }
    }

    private func purchase() {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        errorMessage = nil

        Task {
            do {
                let success = try await subscriptionService.purchase(package: package)
                if success {
                    AnalyticsService.track(.subscriptionStarted, properties: [
                        "package": package.identifier
                    ])
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    private func restore() {
        isPurchasing = true
        errorMessage = nil

        Task {
            do {
                try await subscriptionService.restorePurchases()
                if subscriptionService.isPremium {
                    AnalyticsService.track(.subscriptionRestored)
                    dismiss()
                } else {
                    errorMessage = "No active subscription found."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }
}

// MARK: - Subviews

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ShelfColors.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ShelfFonts.subheadlineBold)
                Text(description)
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.textSecondary)
            }
        }
    }
}

struct PackageOptionView: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(package.storeProduct.localizedTitle)
                        .font(ShelfFonts.subheadlineBold)
                    Text(package.storeProduct.localizedPriceString)
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? ShelfColors.accent : ShelfColors.textSecondary)
            }
            .padding()
            .background(isSelected ? ShelfColors.accentSubtle : ShelfColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: ShelfRadius.large)
                    .stroke(isSelected ? ShelfColors.accent : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PricingCard: View {
    let title: String
    let price: String
    let isPopular: Bool
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ShelfSpacing.xs) {
                    Text(title)
                        .font(ShelfFonts.subheadlineBold)
                    if isPopular {
                        Text("Best Value")
                            .font(ShelfFonts.captionBold)
                            .padding(.horizontal, ShelfSpacing.xs)
                            .padding(.vertical, 2)
                            .background(ShelfColors.accent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(price)
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.textSecondary)
            }
            Spacer()
            Image(systemName: "circle")
                .foregroundStyle(ShelfColors.textSecondary)
        }
        .padding()
        .background(ShelfColors.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))
    }
}
