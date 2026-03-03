import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ImportViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: ShelfSpacing.xxl) {
                if let status = viewModel.importStatus {
                    importProgressView(status)
                } else {
                    importSetupView
                }
            }
            .padding(ShelfSpacing.xxl)
            .navigationTitle("Import Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.isComplete ? "Done" : "Cancel") {
                        viewModel.stopPolling()
                        dismiss()
                    }
                    .font(ShelfFonts.bodySans)
                    .foregroundStyle(ShelfColors.accent)
                }
            }
            .shelfPageBackground()
        }
    }

    private var importSetupView: some View {
        VStack(spacing: ShelfSpacing.xxl) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 48))
                .foregroundStyle(ShelfColors.accent)

            Text("Import your books")
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            Text("Upload your library export from Goodreads or StoryGraph. We'll match your books and import your ratings, reviews, and shelves.")
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
                .multilineTextAlignment(.center)

            // Source picker
            Picker("Source", selection: $viewModel.selectedSource) {
                Text("Goodreads").tag(ImportSource.goodreads)
                Text("StoryGraph").tag(ImportSource.storygraph)
                Text("Kindle").tag(ImportSource.kindle)
                Text("Kobo").tag(ImportSource.kobo)
            }
            .pickerStyle(.segmented)

            Button {
                showFilePicker = true
            } label: {
                Label(filePickerLabel, systemImage: "doc")
                    .shelfPrimaryButton()
            }
            .disabled(viewModel.isUploading)

            if viewModel.isUploading {
                ProgressView("Uploading...")
                    .foregroundStyle(ShelfColors.textSecondary)
            }

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(ShelfFonts.caption)
                    .foregroundStyle(ShelfColors.error)
            }

            Spacer()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    @ViewBuilder
    private func importProgressView(_ status: ImportStatus) -> some View {
        VStack(spacing: ShelfSpacing.xl) {
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
                        .foregroundStyle(ShelfColors.forest)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(ShelfColors.error)
                }
            }

            Text(statusTitle(status))
                .font(ShelfFonts.headlineSerif)
                .foregroundStyle(ShelfColors.textPrimary)

            // Progress bar
            if status.status == .processing {
                VStack(spacing: ShelfSpacing.sm) {
                    ProgressView(value: Double(status.progressPercent), total: 100)
                        .tint(ShelfColors.accent)

                    Text("\(status.progressPercent)%")
                        .font(ShelfFonts.caption)
                        .foregroundStyle(ShelfColors.textSecondary)
                }
            }

            // Stats
            VStack(spacing: ShelfSpacing.sm) {
                statRow("Total books", value: status.totalBooks)
                statRow("Matched", value: status.matched)
                statRow("Needs review", value: status.needsReview)
                statRow("Unmatched", value: status.unmatched)
            }
            .padding(ShelfSpacing.lg)
            .background(ShelfColors.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: ShelfRadius.large))

            Spacer()

            if status.status == .completed {
                Button("Done") {
                    viewModel.stopPolling()
                    dismiss()
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .shelfPrimaryButton()
            }
        }
    }

    private func statRow(_ label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(ShelfFonts.subheadlineSans)
                .foregroundStyle(ShelfColors.textSecondary)
            Spacer()
            Text("\(value)")
                .font(ShelfFonts.subheadlineBold)
                .foregroundStyle(ShelfColors.textPrimary)
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

    private var filePickerLabel: String {
        switch viewModel.selectedSource {
        case .kindle: "Choose TXT File"
        case .kobo: "Choose SQLite File"
        default: "Choose CSV File"
        }
    }

    private var allowedContentTypes: [UTType] {
        switch viewModel.selectedSource {
        case .kindle: [.plainText]
        case .kobo: [.database]
        default: [.commaSeparatedText]
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
