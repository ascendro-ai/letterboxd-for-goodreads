import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .feed

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
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .feed:
            NavigationStack {
                FeedView()
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
