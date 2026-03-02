/// Offline-first sync engine. Queues mutations (rate, review, status changes)
/// locally and replays them when connectivity returns.

import Foundation
import Network

@Observable
final class SyncService {
    static let shared = SyncService()

    private(set) var isOnline = true
    private(set) var isSyncing = false
    private(set) var syncProgress: (completed: Int, total: Int) = (0, 0)

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
        syncProgress = (0, actions.count)
        let decoder = JSONDecoder()

        for action in actions {
            do {
                switch action.actionType {
                case "log_book":
                    if let request = try? decoder.decode(LogBookRequest.self, from: action.payload) {
                        _ = try await userBookService.logBook(request)
                    }
                case "update_book":
                    if let wrapper = try? decoder.decode(UpdateActionPayload.self, from: action.payload) {
                        _ = try await userBookService.updateBook(id: wrapper.id, request: wrapper.request)
                    }
                case "delete_book":
                    if let idWrapper = try? decoder.decode(IDWrapper.self, from: action.payload) {
                        try await userBookService.removeBook(id: idWrapper.id)
                    }
                case "add_to_shelf":
                    if let wrapper = try? decoder.decode(ShelfActionPayload.self, from: action.payload) {
                        try await ShelfService.shared.addBookToShelf(
                            shelfID: wrapper.shelfID,
                            userBookID: wrapper.userBookID
                        )
                    }
                case "remove_from_shelf":
                    if let wrapper = try? decoder.decode(ShelfActionPayload.self, from: action.payload) {
                        try await ShelfService.shared.removeBookFromShelf(
                            shelfID: wrapper.shelfID,
                            userBookID: wrapper.userBookID
                        )
                    }
                default:
                    break
                }
                offlineStore.removePendingAction(action)
            } catch let error as APIError {
                // 409 Conflict: server has newer data — discard local change
                if case .conflict = error {
                    offlineStore.removePendingAction(action)
                } else {
                    action.retryCount += 1
                    // Cap retries at 3 to avoid infinite loops on permanently-failing requests
                    if action.retryCount > 3 {
                        offlineStore.removePendingAction(action)
                    }
                }
            } catch {
                action.retryCount += 1
                if action.retryCount > 3 {
                    offlineStore.removePendingAction(action)
                }
            }

            syncProgress.completed += 1
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

struct ShelfActionPayload: Codable {
    let shelfID: UUID
    let userBookID: UUID

    enum CodingKeys: String, CodingKey {
        case shelfID = "shelf_id"
        case userBookID = "user_book_id"
    }
}
