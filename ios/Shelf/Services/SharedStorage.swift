import Foundation

/// App Group UserDefaults wrapper for sharing data between the main app
/// and the share extension. Uses `group.com.shelf.app` App Group.
enum SharedStorage {
    private static let suiteName = "group.com.shelf.app"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Pending Book URL

    static var pendingBookURL: URL? {
        get {
            defaults?.url(forKey: "pendingBookURL")
        }
        set {
            defaults?.set(newValue, forKey: "pendingBookURL")
        }
    }

    // MARK: - Auth Token (for share extension API calls)

    static var authToken: String? {
        get {
            defaults?.string(forKey: "authToken")
        }
        set {
            defaults?.set(newValue, forKey: "authToken")
        }
    }

    /// Clears the pending book URL after it has been handled.
    static func clearPendingBook() {
        defaults?.removeObject(forKey: "pendingBookURL")
    }
}
