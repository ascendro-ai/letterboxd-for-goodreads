import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @State private var showDeleteConfirmation = false
    @State private var showImport = false
    @State private var showPaywall = false
    @State private var showExportAlert = false
    @State private var isExporting = false
    @State private var hideReadingStats = false

    private let subscriptionService = SubscriptionService.shared

    var body: some View {
        List {
            // Premium upsell
            if !subscriptionService.isPremium {
                Section {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Shelf Premium")
                                    .font(.subheadline.weight(.semibold))
                                Text("Ad-free, unlimited shelves, and more")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Account") {
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("Edit Profile", systemImage: "person.crop.circle")
                }

                Button {
                    showImport = true
                } label: {
                    Label("Import Library", systemImage: "square.and.arrow.down")
                }
            }

            Section("Data") {
                Button {
                    exportData()
                } label: {
                    if isExporting {
                        HStack {
                            Label("Exporting...", systemImage: "arrow.down.doc")
                            Spacer()
                            ProgressView()
                        }
                    } else {
                        Label("Export My Data (JSON)", systemImage: "arrow.down.doc")
                    }
                }
                .disabled(isExporting)
            }

            Section("Preferences") {
                Toggle(isOn: $hideReadingStats) {
                    Label("Hide Reading Stats", systemImage: "eye.slash")
                }
                .onChange(of: hideReadingStats) { _, newValue in
                    Task { await updateHideStats(newValue) }
                }

                NavigationLink {
                    Text("Notification settings")
                        .navigationTitle("Notifications")
                } label: {
                    Label("Notifications", systemImage: "bell")
                }
            }

            Section("Support") {
                Link(destination: URL(string: "https://shelf.app/privacy")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: URL(string: "https://shelf.app/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
            }

            Section {
                Button("Sign Out") {
                    AnalyticsService.track(.signOut)
                    AnalyticsService.resetUser()
                    auth.signOut()
                }
                .foregroundStyle(.red)

                Button("Delete Account") {
                    showDeleteConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task {
                    try? await auth.deleteAccount()
                }
            }
        } message: {
            Text("This will permanently delete your account. Your reviews and ratings will be anonymized.")
        }
        .sheet(isPresented: $showImport) {
            ImportView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Data Export", isPresented: $showExportAlert) {
            Button("OK") {}
        } message: {
            Text("Your data has been prepared. Check your Files app for the export.")
        }
    }

    private func updateHideStats(_ hide: Bool) async {
        struct UpdateProfile: Codable {
            let hideReadingStats: Bool
            enum CodingKeys: String, CodingKey {
                case hideReadingStats = "hide_reading_stats"
            }
        }
        _ = try? await APIClient.shared.request(
            .patch, path: "/me/profile", body: UpdateProfile(hideReadingStats: hide)
        ) as UserProfile
    }

    private func exportData() {
        isExporting = true

        Task {
            do {
                let data: Data = try await APIClient.shared.request(.get, path: "/me/export")
                // Save to documents directory
                let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let fileURL = documentsURL.appendingPathComponent("shelf-export-\(Date().ISO8601Format()).json")
                try data.write(to: fileURL)
                showExportAlert = true
            } catch {
                // Export failed silently
            }
            isExporting = false
        }
    }
}
