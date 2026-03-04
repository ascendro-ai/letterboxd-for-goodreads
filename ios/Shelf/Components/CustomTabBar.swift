import SwiftUI

// MARK: - App Tab

enum AppTab: Int, CaseIterable {
    case shelves, search

    var icon: String {
        switch self {
        case .shelves: "books.vertical"
        case .search: "magnifyingglass"
        }
    }

    var filledIcon: String {
        switch self {
        case .shelves: "books.vertical.fill"
        case .search: "magnifyingglass"
        }
    }

    var label: String {
        switch self {
        case .shelves: "Shelves"
        case .search: "Search"
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(.horizontal, ShelfSpacing.lg)
        .padding(.top, ShelfSpacing.sm)
        .padding(.bottom, ShelfSpacing.xxs)
        .background(
            ShelfColors.surface
                .shadow(
                    color: .black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: -2
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func tabButton(for tab: AppTab) -> some View {
        Button {
            guard selectedTab != tab else { return }
            ShelfHaptics.shared.tabSwitch()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 0) {
                ZStack {
                    if selectedTab == tab {
                        Capsule()
                            .fill(ShelfColors.accent.opacity(0.15))
                            .frame(width: 64, height: 32)
                            .matchedGeometryEffect(id: "tabPill", in: tabNamespace)
                    }

                    Image(systemName: selectedTab == tab ? tab.filledIcon : tab.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(
                            selectedTab == tab ? ShelfColors.accent : ShelfColors.textTertiary
                        )
                }
                .frame(height: 36)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
