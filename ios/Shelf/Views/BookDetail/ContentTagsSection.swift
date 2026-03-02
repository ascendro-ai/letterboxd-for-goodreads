/// Content tags section for book detail view. Shows content warnings and mood
/// tags with voting UI. Tags that reach the vote threshold display as confirmed.

import SwiftUI

@Observable
final class ContentTagsViewModel {
    private(set) var tags: [ContentTag] = []
    private(set) var availableTags: AvailableTags?
    private(set) var isLoading = false

    let workID: UUID

    init(workID: UUID) {
        self.workID = workID
    }

    func load() async {
        isLoading = true
        do {
            tags = try await APIClient.shared.request(.get, path: "/books/\(workID.uuidString)/tags")
        } catch {
            // Tags are non-critical; fail silently
        }
        isLoading = false
    }

    func loadAvailableTags() async {
        do {
            availableTags = try await APIClient.shared.request(.get, path: "/books/tags/available")
        } catch {
            // Non-critical
        }
    }

    func vote(tagName: String) async {
        let request = VoteTagRequest(tagName: tagName)
        do {
            let tag: ContentTag = try await APIClient.shared.request(.post, path: "/books/\(workID.uuidString)/tags/vote", body: request)
            // Replace or append
            if let index = tags.firstIndex(where: { $0.tagName == tag.tagName }) {
                tags[index] = tag
            } else {
                tags.append(tag)
            }
            tags.sort { $0.voteCount > $1.voteCount }
        } catch {
            // Vote failed
        }
    }

    func removeVote(tagName: String) async {
        do {
            try await APIClient.shared.requestVoid(.delete, path: "/books/\(workID.uuidString)/tags/\(tagName)/vote")
            tags.removeAll { $0.tagName == tagName }
        } catch {
            // Removal failed
        }
    }
}

// MARK: - Content Tags Section

struct ContentTagsSection: View {
    @State var viewModel: ContentTagsViewModel
    @State private var showTagPicker = false

    init(workID: UUID) {
        self._viewModel = State(initialValue: ContentTagsViewModel(workID: workID))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content Tags")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button {
                    showTagPicker = true
                } label: {
                    Label("Add Tag", systemImage: "plus.circle")
                        .font(.subheadline)
                }
            }

            if viewModel.tags.isEmpty {
                Text("No tags yet. Be the first to add one!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.tags) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showTagPicker) {
            TagPickerSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: ContentTag

    var body: some View {
        HStack(spacing: 4) {
            if tag.isContentWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            Text(tag.displayName)
                .font(.caption)
            Text("\(tag.voteCount)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(chipColor)
        .clipShape(Capsule())
        .overlay(
            tag.isConfirmed
                ? Capsule().stroke(Color.accentColor, lineWidth: 1)
                : nil
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tag.displayName), \(tag.voteCount) votes\(tag.isConfirmed ? ", confirmed" : "")")
    }

    private var chipColor: Color {
        if tag.isContentWarning {
            return Color.orange.opacity(0.12)
        }
        return Color(.systemGray5)
    }
}

// MARK: - Tag Picker Sheet

struct TagPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ContentTagsViewModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if let available = viewModel.availableTags {
                    List {
                        if !filteredWarnings(available).isEmpty {
                            Section("Content Warnings") {
                                ForEach(filteredWarnings(available), id: \.self) { tag in
                                    tagRow(tag, type: "content_warning")
                                }
                            }
                        }

                        if !filteredMoods(available).isEmpty {
                            Section("Moods") {
                                ForEach(filteredMoods(available), id: \.self) { tag in
                                    tagRow(tag, type: "mood")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search tags")
                } else {
                    LoadingStateView()
                }
            }
            .navigationTitle("Add Content Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await viewModel.loadAvailableTags()
            }
        }
    }

    private func filteredWarnings(_ available: AvailableTags) -> [String] {
        let tags = available.contentWarnings
        if searchText.isEmpty { return tags }
        return tags.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func filteredMoods(_ available: AvailableTags) -> [String] {
        let tags = available.moods
        if searchText.isEmpty { return tags }
        return tags.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    @ViewBuilder
    private func tagRow(_ tagName: String, type: String) -> some View {
        let alreadyVoted = viewModel.tags.contains { $0.tagName == tagName }
        let displayName = tagName.replacingOccurrences(of: "_", with: " ").capitalized

        Button {
            Task {
                if alreadyVoted {
                    await viewModel.removeVote(tagName: tagName)
                } else {
                    await viewModel.vote(tagName: tagName)
                }
            }
        } label: {
            HStack {
                if type == "content_warning" {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
                Text(displayName)
                Spacer()
                if alreadyVoted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
