import Foundation
import SwiftUI

import AppTrackingTransparency

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Ad Configuration

enum AdConfig {
    static let nativeAdUnitID = "ca-app-pub-9251412499428760/2790100544"
    // Show one ad per 8-10 content items — balances revenue with user experience. Premium users see no ads.
    static let minSpacing = 8
    static let maxSpacing = 10
    static let preloadPoolSize = 3
}

// MARK: - Ad Service

@Observable
final class AdService: NSObject {
    static let shared = AdService()

    private let subscriptionService = SubscriptionService.shared

    var shouldShowAds: Bool {
        subscriptionService.adsEnabled && !AdConfig.nativeAdUnitID.isEmpty
    }

    #if canImport(GoogleMobileAds)
    private var adPool: [GADNativeAd] = []
    private var adLoader: GADAdLoader?
    private var isLoadingAds = false
    #endif

    /// Randomized spacing for ad positions — varies between 8-10 to feel less predictable
    private var adSpacing: Int = AdConfig.minSpacing

    private override init() {
        super.init()
        randomizeSpacing()
    }

    // MARK: - Configuration

    func configure() {
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start { [weak self] _ in
            self?.preloadAds()
        }
        #endif
    }

    /// Request App Tracking Transparency authorization for personalized ads.
    func requestTrackingAuthorization() async {
        #if canImport(AppTrackingTransparency)
        await withCheckedContinuation { continuation in
            ATTrackingManager.requestTrackingAuthorization { _ in
                continuation.resume()
            }
        }
        #endif
    }

    // MARK: - Ad Placement

    /// Determines whether to insert an ad at the given feed index.
    func shouldInsertAd(at index: Int) -> Bool {
        guard shouldShowAds else { return false }
        return (index + 1) % adSpacing == 0
    }

    /// Returns the next available preloaded native ad, or nil if pool is empty.
    func nextAd() -> AnyObject? {
        #if canImport(GoogleMobileAds)
        guard !adPool.isEmpty else {
            preloadAds()
            return nil
        }
        let ad = adPool.removeFirst()
        if adPool.count < 2 {
            preloadAds()
        }
        return ad
        #else
        return nil
        #endif
    }

    /// Recalculate ad spacing when feed content changes to keep placement feeling natural.
    func recalculateSpacing() {
        randomizeSpacing()
    }

    // MARK: - Private

    private func randomizeSpacing() {
        adSpacing = Int.random(in: AdConfig.minSpacing...AdConfig.maxSpacing)
    }

    #if canImport(GoogleMobileAds)
    private func preloadAds() {
        guard !isLoadingAds, adPool.count < AdConfig.preloadPoolSize else { return }

        isLoadingAds = true
        let options = GADMultipleAdsAdLoaderOptions()
        options.numberOfAds = AdConfig.preloadPoolSize - adPool.count

        let loader = GADAdLoader(
            adUnitID: AdConfig.nativeAdUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: [options]
        )
        loader.delegate = self
        loader.load(GADRequest())
        adLoader = loader
    }
    #endif
}

// MARK: - GADNativeAdLoaderDelegate

#if canImport(GoogleMobileAds)
extension AdService: GADNativeAdLoaderDelegate {
    func adLoader(_ adLoader: GADAdLoader, didReceive nativeAd: GADNativeAd) {
        adPool.append(nativeAd)
        nativeAd.delegate = self
    }

    func adLoader(_ adLoader: GADAdLoader, didFailToReceiveAdWithError error: Error) {
        AnalyticsService.captureError(error, context: ["source": "ad_loader"])
    }

    func adLoaderDidFinishLoading(_ adLoader: GADAdLoader) {
        isLoadingAds = false
    }
}

extension AdService: GADNativeAdDelegate {
    func nativeAdDidRecordImpression(_ nativeAd: GADNativeAd) {
        AnalyticsService.track(.adImpression)
    }

    func nativeAdDidRecordClick(_ nativeAd: GADNativeAd) {
        AnalyticsService.track(.adClick)
    }
}
#endif
