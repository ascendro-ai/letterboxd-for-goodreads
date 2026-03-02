import XCTest
@testable import Shelf

final class BookDetailViewModelTests: XCTestCase {

    func testInitialState() {
        let vm = BookDetailViewModel(bookID: MockData.workID)
        XCTAssertNil(vm.book)
        XCTAssertTrue(vm.reviews.isEmpty)
        XCTAssertTrue(vm.similarBooks.isEmpty)
        XCTAssertNil(vm.userBook)
        XCTAssertNil(vm.error)
    }

    func testBookIDIsPreserved() {
        let id = UUID()
        let vm = BookDetailViewModel(bookID: id)
        XCTAssertEqual(vm.bookID, id)
    }
}
