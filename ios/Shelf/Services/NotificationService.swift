import Foundation
import UserNotifications
import UIKit

@Observable
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private(set) var isAuthorized = false
    private(set) var deviceToken: String?

    private let api = APIClient.shared

    private override init() {
        super.init()
    }

    // MARK: - Request Permission

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await MainActor.run {
                isAuthorized = granted
            }
            if granted {
                await registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    // MARK: - Register for Remote Notifications

    @MainActor
    private func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    // MARK: - Handle Device Token

    func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token

        Task {
            try? await sendTokenToBackend(token)
        }
    }

    func handleRegistrationError(_ error: Error) {
        AnalyticsService.captureError(error, context: ["source": "push_registration"])
    }

    // MARK: - Handle Incoming Notification

    func handleNotification(_ userInfo: [AnyHashable: Any]) -> NotificationDestination? {
        guard let type = userInfo["type"] as? String else { return nil }

        switch type {
        case "new_follower":
            if let userIDString = userInfo["user_id"] as? String,
               let userID = UUID(uuidString: userIDString) {
                return .profile(userID)
            }
        case "book_activity":
            if let bookIDString = userInfo["book_id"] as? String,
               let bookID = UUID(uuidString: bookIDString) {
                return .bookDetail(bookID)
            }
        case "import_complete":
            return .importStatus
        default:
            break
        }

        return .notifications
    }

    // MARK: - Send Token to Backend

    private func sendTokenToBackend(_ token: String) async throws {
        struct DeviceTokenRequest: Encodable {
            let deviceToken: String
            let platform = "ios"

            enum CodingKeys: String, CodingKey {
                case platform
                case deviceToken = "device_token"
            }
        }

        try await api.request(
            .post,
            path: "/me/devices",
            body: DeviceTokenRequest(deviceToken: token)
        )
    }

    // MARK: - Badge Management

    @MainActor
    func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

// MARK: - Navigation Destination

enum NotificationDestination {
    case profile(UUID)
    case bookDetail(UUID)
    case notifications
    case importStatus
}
