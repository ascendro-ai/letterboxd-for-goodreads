import Foundation
import Network

@Observable
final class SyncService {
    static let shared = SyncService()

    private(set) var isOnline = true
    private(set) var isSyncing = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.shelf.network-monitor")
    private let offlineStore = OfflineStore.shared
    private let userBookService = UserBookService.shared

    private init() {
        startMonitoring()
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied

                // Came back online — sync pending actions
                if wasOffline && path.status == .satisfied {
                    await self?.syncPendingActions()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Pending Actions

    @MainActor
    func syncPendingActions() async {
        guard !isSyncing, isOnline else { return }
        isSyncing = true

        let actions = offlineStore.getPendingActions()
        let decoder = JSONDecoder()

        for action in actions {
            do {
                switch action.actionType {
                case "log_book":
                    if let request = try? decoder.decode(LogBookRequest.self, from: action.payload) {
                        _ = try await userBookService.logBook(request)
                    }
                case "update_book":
                    // Payload contains both ID and request
                    if let wrapper = try? decoder.decode(UpdateActionPayload.self, from: action.payload) {
                        _ = try await userBookService.updateBook(id: wrapper.id, request: wrapper.request)
                    }
                case "delete_book":
                    if let idWrapper = try? decoder.decode(IDWrapper.self, from: action.payload) {
                        try await userBookService.removeBook(id: idWrapper.id)
                    }
                default:
                    break
                }
                offlineStore.removePendingAction(action)
            } catch {
                // Increment retry count, skip if too many failures
                action.retryCount += 1
                if action.retryCount > 3 {
                    offlineStore.removePendingAction(action)
                }
            }
        }

        isSyncing = false
    }
}

// MARK: - Sync Payload Types

struct UpdateActionPayload: Codable {
    let id: UUID
    let request: UpdateBookRequest
}

struct IDWrapper: Codable {
    let id: UUID
}
