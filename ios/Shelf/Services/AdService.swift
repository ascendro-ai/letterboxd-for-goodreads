import Foundation
import SwiftUI

// MARK: - Ad Configuration

enum AdConfig {
    static let nativeAdUnitID = "" // TODO: Set AdMob ad unit ID
    static let adFrequency = 8 // Show ad every N items in feed
}

// MARK: - Ad Service

@Observable
final class AdService {
    static let shared = AdService()

    private let subscriptionService = SubscriptionService.shared

    var shouldShowAds: Bool {
        subscriptionService.adsEnabled && !AdConfig.nativeAdUnitID.isEmpty
    }

    private init() {}

    /// Determines whether to insert an ad at the given feed index.
    func shouldInsertAd(at index: Int) -> Bool {
        guard shouldShowAds else { return false }
        // Ad after every `adFrequency` items, starting after the first batch
        return (index + 1) % AdConfig.adFrequency == 0
    }
}
