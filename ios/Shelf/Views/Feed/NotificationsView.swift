import SwiftUI

struct NotificationsView: View {
    @State private var viewModel = NotificationsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingStateView()
            } else if let error = viewModel.error, viewModel.notifications.isEmpty {
                ErrorStateView(error: error) {
                    Task { await viewModel.refresh() }
                }
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(
                    icon: "bell.slash",
                    title: "No notifications",
                    message: "You're all caught up! Notifications will appear here when friends interact with your reading."
                )
            } else {
                notificationsList
            }
        }
        .shelfPageBackground()
        .navigationTitle("Notifications")
        .task {
            if viewModel.notifications.isEmpty {
                await viewModel.load()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .toolbar {
            if viewModel.unreadCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        Task { await viewModel.markAllRead() }
                    }
                    .font(ShelfFonts.subheadlineSans)
                }
            }
        }
    }

    private var notificationsList: some View {
        List(viewModel.notifications) { notification in
            HStack(spacing: ShelfSpacing.md) {
                if let actor = notification.actor {
                    UserAvatarView(url: actor.avatarURL, size: 36)
                } else {
                    Image(systemName: "bell.fill")
                        .font(.body)
                        .foregroundStyle(notification.isRead ? ShelfColors.textSecondary : ShelfColors.accent)
                }

                VStack(alignment: .leading, spacing: ShelfSpacing.xxs) {
                    Text(notification.title)
                        .font(notification.isRead ? ShelfFonts.subheadlineSans : ShelfFonts.subheadlineBold)
                        .foregroundStyle(ShelfColors.textPrimary)

                    if !notification.body.isEmpty {
                        Text(notification.body)
                            .font(ShelfFonts.caption)
                            .foregroundStyle(ShelfColors.textSecondary)
                            .lineLimit(2)
                    }

                    Text(notification.createdAt.feedTimestamp)
                        .font(ShelfFonts.caption2)
                        .foregroundStyle(ShelfColors.textTertiary)
                }
            }
            .listRowBackground(notification.isRead ? Color.clear : ShelfColors.accentSubtle)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
