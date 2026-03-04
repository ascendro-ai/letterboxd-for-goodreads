import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .shelves
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @State private var deepLinkBookID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            OfflineBannerView()

            ZStack(alignment: .bottom) {
                // Tab content — ZStack with opacity preserves scroll position and state
                ZStack {
                    NavigationStack {
                        ShelvesHomeView()
                            .navigationDestination(item: $deepLinkBookID) { bookID in
                                BookDetailView(bookID: bookID)
                            }
                    }
                    .opacity(selectedTab == .shelves ? 1 : 0)
                    .accessibilityHidden(selectedTab != .shelves)

                    NavigationStack {
                        SearchView()
                    }
                    .opacity(selectedTab == .search ? 1 : 0)
                    .accessibilityHidden(selectedTab != .search)

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                CustomTabBar(selectedTab: $selectedTab)
            }
        }
        .onChange(of: deepLinkHandler.pendingBookID) { _, bookID in
            if let bookID {
                deepLinkBookID = bookID
                selectedTab = .shelves
                deepLinkHandler.clearPending()
            }
        }
        .onChange(of: deepLinkHandler.pendingSearchQuery) { _, query in
            if query != nil {
                selectedTab = .search
                deepLinkHandler.clearPending()
            }
        }
    }
}
