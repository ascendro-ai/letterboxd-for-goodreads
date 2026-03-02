import XCTest
@testable import Shelf

final class SearchViewModelTests: XCTestCase {

    func testInitialStateIsEmpty() {
        let vm = SearchViewModel()
        XCTAssertEqual(vm.query, "")
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertFalse(vm.isSearching)
        XCTAssertFalse(vm.hasSearched)
        XCTAssertNil(vm.error)
    }

    func testClearResetsState() {
        let vm = SearchViewModel()
        vm.query = "Gatsby"
        vm.clear()

        XCTAssertEqual(vm.query, "")
        XCTAssertTrue(vm.results.isEmpty)
        XCTAssertFalse(vm.hasSearched)
    }

    func testEmptyQueryDoesNotSearch() {
        let vm = SearchViewModel()
        vm.query = ""
        vm.search()
        // Should remain in initial state
        XCTAssertFalse(vm.isSearching)
        XCTAssertTrue(vm.results.isEmpty)
    }
}
