import SwiftUI

struct SeriesDetailView: View {
    let seriesID: UUID
    let seriesName: String

    @State private var series: Series?
    @State private var progress: SeriesProgress?
    @State private var isLoading = false
    @State private var error: Error?

    private let seriesService = SeriesService.shared

    var body: some View {
        Group {
            if isLoading && series == nil {
                LoadingStateView()
            } else if let error, series == nil {
                ErrorStateView(error: error) {
                    Task { await load() }
                }
            } else if let series {
                seriesContent(series)
            }
        }
        .navigationTitle(seriesName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if series == nil { await load() }
        }
    }

    @ViewBuilder
    private func seriesContent(_ series: Series) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Progress header
                if let progress {
                    VStack(spacing: 8) {
                        ProgressView(value: progress.progressPercent, total: 100)
                            .tint(.accentColor)

                        HStack {
                            Text("\(progress.readCount) of \(progress.totalMainEntries) read")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if progress.readingCount > 0 {
                                Text("(\(progress.readingCount) reading)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text("\(Int(progress.progressPercent))%")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.horizontal)
                }

                if let description = series.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                // Book list
                LazyVStack(spacing: 0) {
                    ForEach(series.works) { work in
                        HStack(spacing: 12) {
                            // Position number
                            Text(positionText(work.position))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)

                            // Cover
                            BookCoverImage(
                                url: work.coverImageURL,
                                size: CGSize(width: 40, height: 60),
                                bookTitle: work.title
                            )

                            // Title + author + status
                            VStack(alignment: .leading, spacing: 4) {
                                Text(work.title)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(2)

                                if let author = work.authors.first {
                                    Text(author)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            // Reading status indicator
                            statusIcon(work.userStatus)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: String?) -> some View {
        switch status {
        case "read":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Read")
        case "reading":
            Image(systemName: "book.fill")
                .foregroundStyle(.blue)
                .accessibilityLabel("Currently reading")
        case "want_to_read":
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.orange)
                .accessibilityLabel("Want to read")
        default:
            Image(systemName: "circle")
                .foregroundStyle(.quaternary)
                .accessibilityLabel("Not started")
        }
    }

    private func positionText(_ position: Double) -> String {
        position.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", position)
            : String(format: "%.1f", position)
    }

    @MainActor
    private func load() async {
        isLoading = true
        error = nil

        do {
            async let seriesResult = seriesService.getSeries(id: seriesID)
            async let progressResult = seriesService.getSeriesProgress(id: seriesID)

            let (s, p) = try await (seriesResult, progressResult)
            series = s
            progress = p
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
