import XCTest
@testable import Shelf

final class FeedViewModelTests: XCTestCase {

    func testInitialStateIsEmpty() {
        let vm = FeedViewModel()
        XCTAssertTrue(vm.items.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.isLoadingMore)
        XCTAssertNil(vm.error)
    }
}
