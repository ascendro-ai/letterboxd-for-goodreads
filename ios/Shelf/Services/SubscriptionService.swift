import Foundation
import RevenueCat

@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    private(set) var isPremium = false
    private(set) var currentOffering: Offering?
    private(set) var activeSubscription: EntitlementInfo?

    static let entitlementID = "premium"
    static let apiKey = "" // TODO: Set RevenueCat API key

    private init() {}

    // MARK: - Configuration

    func configure() {
        guard !Self.apiKey.isEmpty else { return }
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Self.apiKey)
    }

    func configureUser(userID: String) {
        guard !Self.apiKey.isEmpty else { return }
        Purchases.shared.logIn(userID) { _, _, _ in }
    }

    // MARK: - Check Status

    @MainActor
    func checkSubscriptionStatus() async {
        guard !Self.apiKey.isEmpty else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            updateStatus(from: customerInfo)
        } catch {
            // Default to free tier on error
            isPremium = false
        }
    }

    // MARK: - Fetch Offerings

    @MainActor
    func fetchOfferings() async {
        guard !Self.apiKey.isEmpty else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            currentOffering = offerings.current
        } catch {
            // Offerings unavailable
        }
    }

    // MARK: - Purchase

    @MainActor
    func purchase(package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        updateStatus(from: result.customerInfo)
        return !result.userCancelled
    }

    // MARK: - Restore

    @MainActor
    func restorePurchases() async throws {
        let customerInfo = try await Purchases.shared.restorePurchases()
        updateStatus(from: customerInfo)
    }

    // MARK: - Premium Feature Checks

    var maxShelves: Int {
        isPremium ? 50 : 20
    }

    var adsEnabled: Bool {
        !isPremium
    }

    // MARK: - Private

    private func updateStatus(from customerInfo: CustomerInfo) {
        let entitlement = customerInfo.entitlements[Self.entitlementID]
        isPremium = entitlement?.isActive == true
        activeSubscription = entitlement
    }
}
