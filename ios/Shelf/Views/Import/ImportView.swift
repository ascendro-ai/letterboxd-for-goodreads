import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let status = viewModel.importStatus {
                    importProgressView(status)
                } else {
                    importSetupView
                }
            }
            .padding(24)
            .navigationTitle("Import Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.isComplete ? "Done" : "Cancel") {
                        viewModel.stopPolling()
                        dismiss()
                    }
                }
            }
        }
    }

    private var importSetupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Import your books")
                .font(.title3.bold())

            Text("Upload your library export from Goodreads or StoryGraph. We'll match your books and import your ratings, reviews, and shelves.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Source picker
            Picker("Source", selection: $viewModel.selectedSource) {
                Text("Goodreads").tag(ImportSource.goodreads)
                Text("StoryGraph").tag(ImportSource.storygraph)
            }
            .pickerStyle(.segmented)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose CSV File", systemImage: "doc")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.isUploading)

            if viewModel.isUploading {
                ProgressView("Uploading...")
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    @ViewBuilder
    private func importProgressView(_ status: ImportStatus) -> some View {
        VStack(spacing: 20) {
            Spacer()

            // Status icon
            Group {
                switch status.status {
                case .processing, .pending:
                    ProgressView()
                        .scaleEffect(1.5)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                }
            }

            Text(statusTitle(status))
                .font(.title3.bold())

            // Progress bar
            if status.status == .processing {
                VStack(spacing: 8) {
                    ProgressView(value: Double(status.progressPercent), total: 100)
                        .tint(.accentColor)

                    Text("\(status.progressPercent)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Stats
            VStack(spacing: 8) {
                statRow("Total books", value: status.totalBooks)
                statRow("Matched", value: status.matched)
                statRow("Needs review", value: status.needsReview)
                statRow("Unmatched", value: status.unmatched)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            if status.status == .completed {
                Button("Done") {
                    viewModel.stopPolling()
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func statRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
        }
    }

    private func statusTitle(_ status: ImportStatus) -> String {
        switch status.status {
        case .pending: "Queued..."
        case .processing: "Importing your library..."
        case .completed: "Import complete!"
        case .failed: "Import failed"
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let data = try? Data(contentsOf: url) {
                Task {
                    await viewModel.uploadCSV(data: data)
                }
            }
        case .failure:
            break
        }
    }
}
