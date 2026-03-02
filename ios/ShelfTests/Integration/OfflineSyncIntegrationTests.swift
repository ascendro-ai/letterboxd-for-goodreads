import XCTest
@testable import Shelf

final class OfflineSyncIntegrationTests: XCTestCase {

    func testSyncServiceSingleton() {
        let sync1 = SyncService.shared
        let sync2 = SyncService.shared
        XCTAssertTrue(sync1 === sync2)
    }

    func testSyncServiceInitialState() {
        let sync = SyncService.shared
        XCTAssertFalse(sync.isSyncing)
    }

    func testOfflineStoreSingleton() {
        let store1 = OfflineStore.shared
        let store2 = OfflineStore.shared
        XCTAssertTrue(store1 === store2)
    }
}
