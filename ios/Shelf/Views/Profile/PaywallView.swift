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
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.yellow)

                        Text("Shelf Premium")
                            .font(.title.bold())

                        Text("Get the most out of your reading life")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        PremiumFeatureRow(icon: "eye.slash", title: "Ad-free experience", description: "No ads, ever.")
                        PremiumFeatureRow(icon: "books.vertical", title: "Unlimited shelves", description: "Create as many shelves as you want.")
                        PremiumFeatureRow(icon: "chart.bar", title: "Advanced stats", description: "Deep insights into your reading habits.")
                        PremiumFeatureRow(icon: "paintpalette", title: "Custom themes", description: "Personalize your profile.")
                        PremiumFeatureRow(icon: "calendar", title: "Enhanced Year in Review", description: "Beautiful reading year summary.")
                    }
                    .padding(.horizontal)

                    // Package options
                    if let offering = subscriptionService.currentOffering {
                        VStack(spacing: 12) {
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
                        VStack(spacing: 12) {
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
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isPurchasing || selectedPackage == nil)
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    // Restore
                    Button("Restore Purchases") {
                        restore()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    // Legal
                    Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the current period ends.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                }
            }
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
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                        .font(.subheadline.weight(.semibold))
                    Text(package.storeProduct.localizedPriceString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
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
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    if isPopular {
                        Text("Best Value")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(price)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
