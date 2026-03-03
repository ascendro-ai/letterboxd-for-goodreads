import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .feed
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @State private var deepLinkBookID: UUID?

    enum Tab: String, CaseIterable {
        case feed, search, log, notifications, profile

        var title: String {
            switch self {
            case .feed: "Feed"
            case .search: "Search"
            case .log: "Log"
            case .notifications: "Notifications"
            case .profile: "Profile"
            }
        }

        var icon: String {
            switch self {
            case .feed: "book"
            case .search: "magnifyingglass"
            case .log: "square.and.pencil"
            case .notifications: "bell"
            case .profile: "person.crop.rectangle.stack"
            }
        }

        var selectedIcon: String {
            switch self {
            case .feed: "book.fill"
            case .search: "magnifyingglass"
            case .log: "square.and.pencil"
            case .notifications: "bell.fill"
            case .profile: "person.crop.rectangle.stack.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OfflineBannerView()

            TabView(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    tabContent(for: tab)
                        .tabItem {
                            Label(tab.title, systemImage: selectedTab == tab ? tab.selectedIcon : tab.icon)
                        }
                        .tag(tab)
                }
            }
            .tint(ShelfColors.accent)
        }
        .onChange(of: deepLinkHandler.pendingBookID) { _, bookID in
            if let bookID {
                deepLinkBookID = bookID
                selectedTab = .feed
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

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .feed:
            NavigationStack {
                FeedView()
                    .navigationDestination(item: $deepLinkBookID) { bookID in
                        BookDetailView(bookID: bookID)
                    }
            }
        case .search:
            NavigationStack {
                SearchView()
            }
        case .log:
            NavigationStack {
                LogView()
            }
        case .notifications:
            NavigationStack {
                NotificationsView()
            }
        case .profile:
            NavigationStack {
                MyProfileView()
            }
        }
    }
}
