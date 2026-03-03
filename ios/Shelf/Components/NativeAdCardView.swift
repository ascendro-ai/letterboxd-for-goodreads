import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Native ad card styled to match the feed's visual language.
/// When GoogleMobileAds SDK is available, wraps a real GADNativeAdView.
/// Otherwise shows a placeholder shimmer layout.
struct NativeAdCardView: View {
    private let adService = AdService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: ShelfSpacing.sm) {
            HStack(spacing: ShelfSpacing.xs) {
                Text("Sponsored")
                    .font(ShelfFonts.captionBold)
                    .foregroundStyle(ShelfColors.textSecondary)
                    .padding(.horizontal, ShelfSpacing.xs)
                    .padding(.vertical, 2)
                    .background(ShelfColors.backgroundTertiary)
                    .clipShape(Capsule())
                Spacer()
            }

            #if canImport(GoogleMobileAds)
            if let nativeAd = adService.nextAd() as? GADNativeAd {
                NativeAdRepresentable(nativeAd: nativeAd)
                    .frame(height: 90)
            } else {
                placeholderContent
            }
            #else
            placeholderContent
            #endif
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .accessibilityLabel("Sponsored content")
    }

    private var placeholderContent: some View {
        HStack(spacing: ShelfSpacing.md) {
            RoundedRectangle(cornerRadius: ShelfRadius.small)
                .fill(ShelfColors.backgroundTertiary)
                .frame(width: 60, height: 90)

            VStack(alignment: .leading, spacing: ShelfSpacing.xxs) {
                RoundedRectangle(cornerRadius: ShelfRadius.small)
                    .fill(ShelfColors.backgroundTertiary)
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: ShelfRadius.small)
                    .fill(ShelfColors.backgroundSecondary)
                    .frame(width: 120, height: 12)
                Spacer()
            }
        }
        .frame(height: 90)
        .redacted(reason: .placeholder)
    }
}

// MARK: - GADNativeAdView UIViewRepresentable

#if canImport(GoogleMobileAds)
struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: GADNativeAd

    func makeUIView(context: Context) -> GADNativeAdView {
        let adView = GADNativeAdView()
        adView.backgroundColor = .clear

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .preferredFont(forTextStyle: .subheadline)
        headlineLabel.numberOfLines = 2
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel

        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .preferredFont(forTextStyle: .caption1)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel

        // Media
        let mediaView = GADMediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = 6
        adView.addSubview(mediaView)
        adView.mediaView = mediaView

        // CTA button
        let ctaButton = UIButton(type: .system)
        ctaButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote).withTraits(.traitBold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = UIColor.tintColor
        ctaButton.layer.cornerRadius = 6
        ctaButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton

        // Layout: [Media 60x90] [Headline / Body / CTA]
        NSLayoutConstraint.activate([
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
            mediaView.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
            mediaView.widthAnchor.constraint(equalToConstant: 60),

            headlineLabel.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 12),
            headlineLabel.topAnchor.constraint(equalTo: adView.topAnchor),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor),

            ctaButton.leadingAnchor.constraint(equalTo: headlineLabel.leadingAnchor),
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor),
        ])

        return adView
    }

    func updateUIView(_ adView: GADNativeAdView, context: Context) {
        adView.nativeAd = nativeAd

        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionView?.isUserInteractionEnabled = false
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
#endif
