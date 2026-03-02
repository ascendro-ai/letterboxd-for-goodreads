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
                    .font(.subheadline)
                }
            }
        }
    }

    private var notificationsList: some View {
        List(viewModel.notifications) { notification in
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundStyle(notification.isRead ? Color.secondary : Color.accentColor)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.subheadline.weight(notification.isRead ? .regular : .semibold))

                    Text(notification.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(notification.createdAt.feedTimestamp)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(notification.isRead ? "" : "Unread. ")\(notification.title). \(notification.body)")
            .listRowBackground(notification.isRead ? Color.clear : Color.accentColor.opacity(0.05))
        }
        .listStyle(.plain)
    }
}
