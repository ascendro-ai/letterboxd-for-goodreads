import SwiftUI

/// Orange banner shown when the device is offline, with optional sync progress.
struct OfflineBannerView: View {
    @State private var syncService = SyncService.shared
    @State private var offlineStore = OfflineStore.shared

    var body: some View {
        if !syncService.isOnline {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)

                Text("You're offline")
                    .font(.caption.weight(.medium))

                Spacer()

                if syncService.isSyncing {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Syncing...")
                        .font(.caption2)
                } else {
                    let pendingCount = offlineStore.pendingActionCount()
                    if pendingCount > 0 {
                        Text("\(pendingCount) pending")
                            .font(.caption2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .foregroundStyle(.white)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You're offline. \(syncService.isSyncing ? "Syncing changes." : "")")
        }
    }
}

// MARK: - View Modifier

extension View {
    func offlineBanner() -> some View {
        VStack(spacing: 0) {
            OfflineBannerView()
            self
        }
    }
}
