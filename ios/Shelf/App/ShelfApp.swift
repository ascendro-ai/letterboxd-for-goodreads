/// App entry point. Configures the SwiftUI environment with shared services
/// (auth, analytics, subscriptions) and handles deep links and push notifications.

import SwiftUI

@main
struct ShelfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authService = AuthService.shared
    @State private var deepLinkHandler = DeepLinkHandler.shared

    init() {
        // Initialize SDKs
        AnalyticsService.configure()
        SubscriptionService.shared.configure()
        AdService.shared.configure()

        // Configure global appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(deepLinkHandler)
                .onOpenURL { url in
                    deepLinkHandler.handle(url)
                }
                .task {
                    await authService.restoreSession()

                    // Post-auth setup
                    if let user = authService.currentUser {
                        AnalyticsService.identifyUser(id: user.id.uuidString, properties: [
                            "username": user.username
                        ])
                        SubscriptionService.shared.configureUser(userID: user.id.uuidString)
                        await SubscriptionService.shared.checkSubscriptionStatus()

                        // Sync auth token to shared storage for share extension
                        SharedStorage.authToken = APIClient.shared.authToken
                    }

                    // Request ATT for non-premium users (AdMob personalization)
                    #if !DEBUG
                    if !SubscriptionService.shared.isPremium {
                        await AdService.shared.requestTrackingAuthorization()
                    }
                    #endif

                    // Check for pending book from share extension
                    if let pendingURL = SharedStorage.pendingBookURL {
                        deepLinkHandler.handle(pendingURL)
                        SharedStorage.clearPendingBook()
                    }
                }
        }
    }

    private func configureAppearance() {
        // Tab bar
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(ShelfColors.surface)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(ShelfColors.accent)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(ShelfColors.accent)
        ]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(ShelfColors.textTertiary)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(ShelfColors.textTertiary)
        ]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(ShelfColors.background)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(ShelfColors.textPrimary)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(ShelfColors.textPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(ShelfColors.accent)

        // Table/List separator
        UITableView.appearance().separatorColor = UIColor(ShelfColors.divider)
    }
}

// MARK: - App Delegate for Push Notifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationService.shared.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationService.shared.handleRegistrationError(error)
    }

    // Handle notification tap when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }

    // Handle notification tap when app is in background
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        _ = NotificationService.shared.handleNotification(userInfo)
    }
}

// MARK: - Root View with Onboarding

struct RootView: View {
    @Environment(AuthService.self) private var auth
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        switch auth.state {
        case .unknown:
            LaunchScreen()
        case .signedOut:
            AuthView()
        case .signedIn:
            if hasCompletedOnboarding {
                ContentView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .environment(auth)
            }
        }
    }
}

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            ShelfColors.background
                .ignoresSafeArea()
            VStack(spacing: ShelfSpacing.md) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(ShelfColors.accent)
                    .symbolEffect(.pulse)
                Text("Shelf")
                    .font(ShelfFonts.displayLarge)
                    .foregroundStyle(ShelfColors.textPrimary)
            }
        }
    }
}
