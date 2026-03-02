import SwiftUI

@main
struct ShelfApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authService = AuthService.shared

    init() {
        // Initialize SDKs
        AnalyticsService.configure()
        SubscriptionService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .task {
                    await authService.restoreSession()

                    // Post-auth setup
                    if let user = authService.currentUser {
                        AnalyticsService.identifyUser(id: user.id.uuidString, properties: [
                            "username": user.username
                        ])
                        SubscriptionService.shared.configureUser(userID: user.id.uuidString)
                        await SubscriptionService.shared.checkSubscriptionStatus()
                    }
                }
        }
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
        // TODO: Navigate to destination via a shared navigation state
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
            Color(.systemBackground)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                Text("Shelf")
                    .font(.title.bold())
            }
        }
    }
}
