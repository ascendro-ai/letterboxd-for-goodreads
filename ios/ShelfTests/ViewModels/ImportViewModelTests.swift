import XCTest
@testable import Shelf

final class ImportViewModelTests: XCTestCase {

    func testInitialState() {
        let vm = ImportViewModel()
        XCTAssertNil(vm.importStatus)
        XCTAssertFalse(vm.isUploading)
        XCTAssertFalse(vm.isPolling)
        XCTAssertNil(vm.error)
        XCTAssertFalse(vm.isComplete)
    }

    func testSelectedSourceDefault() {
        let vm = ImportViewModel()
        XCTAssertEqual(vm.selectedSource, .goodreads)
    }
}
