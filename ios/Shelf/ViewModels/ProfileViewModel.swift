import Foundation

@Observable
final class ProfileViewModel {
    private(set) var profile: UserProfile?
    private(set) var books: [UserBook] = []
    private(set) var shelves: [Shelf] = []
    private(set) var isLoading = false
    private(set) var error: Error?
    private(set) var selectedStatus: ReadingStatus? = nil
    private(set) var isOffline = false

    private let socialService = SocialService.shared
    private let userBookService = UserBookService.shared
    private let shelfService = ShelfService.shared
    private let offlineStore = OfflineStore.shared
    private let syncService = SyncService.shared

    let userID: UUID?  // nil = current user

    init(userID: UUID? = nil) {
        self.userID = userID
    }

    var isOwnProfile: Bool { userID == nil }

    @MainActor
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        isOffline = !syncService.isOnline

        do {
            if let userID {
                async let profileResult = socialService.getProfile(userID: userID)
                async let booksResult = userBookService.getUserBooks(userID: userID)
                async let shelvesResult = shelfService.getUserShelves(userID: userID)

                let (p, b, s) = try await (profileResult, booksResult, shelvesResult)
                profile = p
                books = b.items
                shelves = s

                // Cache books for offline
                offlineStore.cacheUserBooks(b.items)
            } else {
                async let userResult = socialService.getMyProfile()
                async let booksResult = userBookService.getMyBooks()
                async let shelvesResult = shelfService.getMyShelves()

                let (u, b, s) = try await (userResult, booksResult, shelvesResult)
                profile = UserProfile(
                    user: u,
                    booksCount: b.items.count,
                    followersCount: 0,
                    followingCount: 0,
                    isFollowing: nil,
                    isBlocked: nil,
                    isMuted: nil
                )
                books = b.items
                shelves = s

                // Cache own books for offline
                offlineStore.cacheUserBooks(b.items)
            }
        } catch {
            self.error = error
        }

        isLoading = false
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
