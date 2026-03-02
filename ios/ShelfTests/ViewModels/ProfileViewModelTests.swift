import XCTest
@testable import Shelf

final class ProfileViewModelTests: XCTestCase {

    func testInitialStateOwnProfile() {
        let vm = ProfileViewModel()
        XCTAssertNil(vm.profile)
        XCTAssertTrue(vm.books.isEmpty)
        XCTAssertTrue(vm.shelves.isEmpty)
        XCTAssertFalse(vm.isLoading)
        XCTAssertNil(vm.error)
        XCTAssertNil(vm.selectedStatus)
        XCTAssertTrue(vm.isOwnProfile)
    }

    func testInitialStateOtherProfile() {
        let vm = ProfileViewModel(userID: MockData.otherUserID)
        XCTAssertFalse(vm.isOwnProfile)
    }
}
