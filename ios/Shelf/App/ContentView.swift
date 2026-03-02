import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .feed
    @State private var searchNavigationPath = NavigationPath()

    private let router = DeepLinkRouter.shared

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
            case .feed: "house"
            case .search: "magnifyingglass"
            case .log: "plus.circle"
            case .notifications: "bell"
            case .profile: "person"
            }
        }

        var selectedIcon: String {
            switch self {
            case .feed: "house.fill"
            case .search: "magnifyingglass"
            case .log: "plus.circle.fill"
            case .notifications: "bell.fill"
            case .profile: "person.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: selectedTab == tab ? tab.selectedIcon : tab.icon)
                    }
                    .tag(tab)
            }
        }
        .onChange(of: router.selectedTab) { _, newTab in
            if let newTab {
                selectedTab = newTab
                router.selectedTab = nil
            }
        }
        .onChange(of: router.pendingDestination) { _, destination in
            guard let destination else { return }
            switch destination {
            case .bookDetail(let id):
                searchNavigationPath.append(BookNavigation.detail(id))
            case .search:
                break // Handled by SearchView observing the router
            case .userProfile(let id):
                searchNavigationPath.append(BookNavigation.userProfile(id))
            }
            router.pendingDestination = nil
        }
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .feed:
            NavigationStack {
                FeedView()
            }
        case .search:
            NavigationStack(path: $searchNavigationPath) {
                SearchView()
                    .navigationDestination(for: BookNavigation.self) { nav in
                        switch nav {
                        case .detail(let id):
                            BookDetailView(bookID: id)
                        case .userProfile(let id):
                            UserProfileView(userID: id)
                        }
                    }
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

/// Navigation values for deep linking into the search tab's NavigationStack.
enum BookNavigation: Hashable {
    case detail(UUID)
    case userProfile(UUID)
}
