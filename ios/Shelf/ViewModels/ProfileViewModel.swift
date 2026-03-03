import Foundation
import os.log

private let logger = Logger(subsystem: "com.shelf.app", category: "Profile")

@Observable
final class ProfileViewModel {
    private(set) var profile: UserProfile?
    private(set) var books: [UserBook] = []
    private(set) var shelves: [Shelf] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var selectedStatus: ReadingStatus? = nil

    private let socialService = SocialService.shared
    private let userBookService = UserBookService.shared
    private let shelfService = ShelfService.shared

    let userID: UUID?  // nil = current user

    init(userID: UUID? = nil) {
        self.userID = userID
    }

    var isOwnProfile: Bool { userID == nil }

    @MainActor
    func load() async {
        logger.info("ProfileViewModel.load() called, isLoading=\(self.isLoading), userID=\(self.userID?.uuidString ?? "nil (own)")")
        guard !isLoading else {
            logger.warning("ProfileViewModel.load() skipped — already loading")
            return
        }
        isLoading = true
        error = nil

        if let userID {
            do {
                profile = try await socialService.getProfile(userID: userID)
            } catch {
                logger.error("Failed to load other user profile: \(error.localizedDescription)")
                self.error = error
            }
            do { books = try await userBookService.getUserBooks(userID: userID).items } catch {}
            do { shelves = try await shelfService.getUserShelves(userID: userID) } catch {}
        } else {
            do {
                logger.info("Calling getMyProfile()...")
                profile = try await socialService.getMyProfile()
                logger.info("getMyProfile() succeeded: \(self.profile?.user.username ?? "nil")")
            } catch {
                logger.error("Failed to load own profile: \(error)")
                self.error = error
            }

            do {
                books = try await userBookService.getMyBooks().items
                logger.info("getMyBooks() returned \(self.books.count) books")
            } catch {
                logger.error("Failed to load books: \(error)")
            }

            do {
                shelves = try await shelfService.getMyShelves()
                logger.info("getMyShelves() returned \(self.shelves.count) shelves")
            } catch {
                logger.error("Failed to load shelves: \(error)")
            }
        }

        isLoading = false
        logger.info("ProfileViewModel.load() done — profile=\(self.profile != nil), error=\(self.error != nil)")
    }

    @MainActor
    func filterBooks(by status: ReadingStatus?) async {
        selectedStatus = status
        do {
            if let userID {
                let response = try await userBookService.getUserBooks(userID: userID, status: status)
                books = response.items
            } else {
                let response = try await userBookService.getMyBooks(status: status)
                books = response.items
            }
        } catch {
            // Keep existing books on filter error
        }
    }

    @MainActor
    func toggleFollow() async throws {
        guard let userID, let profile else { return }
        if profile.isFollowing == true {
            try await socialService.unfollow(userID: userID)
        } else {
            try await socialService.follow(userID: userID)
        }
        await load()
    }
}
