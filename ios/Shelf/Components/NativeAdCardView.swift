import SwiftUI

/// Placeholder for Google AdMob native ad card.
/// Once GoogleMobileAds SPM package is added, this will wrap GADNativeAdView.
/// For now, this provides the layout structure that will contain the real ad.
struct NativeAdCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Sponsored")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .clipShape(Capsule())
                Spacer()
            }

            // Ad content placeholder — will be replaced by GADNativeAdView
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 90)

                VStack(alignment: .leading, spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray6))
                        .frame(width: 120, height: 12)
                    Spacer()
                }
            }
            .frame(height: 90)
            .redacted(reason: .placeholder)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - AdMob Integration Notes
//
// To fully integrate AdMob native ads:
//
// 1. Add SPM dependency:
//    GoogleMobileAds: https://github.com/googleads/swift-package-manager-google-mobile-ads
//    from: "11.0.0"
//
// 2. Add GADApplicationIdentifier to Info.plist
//
// 3. Replace NativeAdCardView with a UIViewRepresentable wrapping GADNativeAdView:
//
//    struct AdMobNativeAdView: UIViewRepresentable {
//        let adUnitID: String
//        func makeUIView(context: Context) -> GADNativeAdView { ... }
//        func updateUIView(_ view: GADNativeAdView, context: Context) { ... }
//    }
//
// 4. Load ads via GADAdLoader in a view model, cache loaded ads
//
// 5. Style the native ad to match BookCard / FeedItemView appearance
