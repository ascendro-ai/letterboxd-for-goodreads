import Foundation
import Sentry
import PostHog

enum AnalyticsService {
    // TODO: Set DSNs before release
    static let sentryDSN = ""
    static let postHogAPIKey = ""
    static let postHogHost = "https://us.i.posthog.com"

    // MARK: - Initialization

    static func configure() {
        configureSentry()
        configurePostHog()
    }

    private static func configureSentry() {
        guard !sentryDSN.isEmpty else { return }
        SentrySDK.start { options in
            options.dsn = sentryDSN
            options.tracesSampleRate = 0.2
            options.profilesSampleRate = 0.1
            options.attachScreenshot = true
            options.enableMetricKit = true
            #if DEBUG
            options.enabled = false
            #endif
        }
    }

    private static func configurePostHog() {
        guard !postHogAPIKey.isEmpty else { return }
        let config = PostHogConfig(apiKey: postHogAPIKey, host: postHogHost)
        config.captureScreenViews = true
        config.captureApplicationLifecycleEvents = true
        #if DEBUG
        config.optOut = true
        #endif
        PostHogSDK.shared.setup(config)
    }

    // MARK: - User Identity

    static func identifyUser(id: String, properties: [String: Any] = [:]) {
        SentrySDK.setUser(Sentry.User(userId: id))
        if !postHogAPIKey.isEmpty {
            PostHogSDK.shared.identify(id, userProperties: properties)
        }
    }

    static func resetUser() {
        SentrySDK.setUser(nil)
        if !postHogAPIKey.isEmpty {
            PostHogSDK.shared.reset()
        }
    }

    // MARK: - Events

    static func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        guard !postHogAPIKey.isEmpty else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    // MARK: - Errors

    static func captureError(_ error: Error, context: [String: Any] = [:]) {
        SentrySDK.capture(error: error) { scope in
            for (key, value) in context {
                scope.setExtra(value: value, key: key)
            }
        }
    }

    static func captureMessage(_ message: String) {
        SentrySDK.capture(message: message)
    }
}

// MARK: - Event Names

enum AnalyticsEvent: String {
    // Auth
    case signUp = "sign_up"
    case signIn = "sign_in"
    case signOut = "sign_out"

    // Books
    case bookSearched = "book_searched"
    case bookViewed = "book_viewed"
    case bookLogged = "book_logged"
    case bookRated = "book_rated"
    case bookReviewed = "book_reviewed"
    case barcodeScanned = "barcode_scanned"

    // Social
    case userFollowed = "user_followed"
    case userUnfollowed = "user_unfollowed"
    case userBlocked = "user_blocked"

    // Shelves
    case shelfCreated = "shelf_created"
    case bookAddedToShelf = "book_added_to_shelf"

    // Import
    case importStarted = "import_started"
    case importCompleted = "import_completed"

    // Subscription
    case paywallViewed = "paywall_viewed"
    case subscriptionStarted = "subscription_started"
    case subscriptionRestored = "subscription_restored"

    // Engagement
    case affiliateLinkTapped = "affiliate_link_tapped"
    case shareExtensionUsed = "share_extension_used"
}
