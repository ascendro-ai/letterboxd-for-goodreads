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
        .shelfPageBackground()
    }

    @ViewBuilder
    private func seriesContent(_ series: Series) -> some View {
        ScrollView {
            VStack(spacing: ShelfSpacing.lg) {
                // Progress header
                if let progress {
                    VStack(spacing: ShelfSpacing.sm) {
                        ProgressView(value: progress.progressPercent, total: 100)
                            .tint(ShelfColors.accent)

                        HStack {
                            Text("\(progress.readCount) of \(progress.totalMainEntries) read")
                                .font(ShelfFonts.subheadlineSans)
                                .foregroundStyle(ShelfColors.textSecondary)
                            if progress.readingCount > 0 {
                                Text("(\(progress.readingCount) reading)")
                                    .font(ShelfFonts.caption)
                                    .foregroundStyle(ShelfColors.textTertiary)
                            }
                            Spacer()
                            Text("\(Int(progress.progressPercent))%")
                                .font(ShelfFonts.subheadlineBold)
                        }
                    }
                    .padding(.horizontal, ShelfSpacing.lg)
                }

                if let description = series.description, !description.isEmpty {
                    Text(description)
                        .font(ShelfFonts.subheadlineSans)
                        .foregroundStyle(ShelfColors.textSecondary)
                        .padding(.horizontal, ShelfSpacing.lg)
                }

                // Book list
                LazyVStack(spacing: 0) {
                    ForEach(series.works) { work in
                        HStack(spacing: ShelfSpacing.md) {
                            // Position number
                            Text(positionText(work.position))
                                .font(ShelfFonts.caption.monospacedDigit())
                                .foregroundStyle(ShelfColors.textSecondary)
                                .frame(width: 28, alignment: .trailing)

                            // Cover
                            BookCoverImage(
                                url: work.coverImageURL,
                                size: CGSize(width: 40, height: 60),
                                bookTitle: work.title
                            )

                            // Title + author + status
                            VStack(alignment: .leading, spacing: ShelfSpacing.xxs) {
                                Text(work.title)
                                    .font(ShelfFonts.bodySerifBold)
                                    .lineLimit(2)
                                    .foregroundStyle(ShelfColors.textPrimary)

                                if let author = work.authors.first {
                                    Text(author)
                                        .font(ShelfFonts.captionSerif)
                                        .foregroundStyle(ShelfColors.textSecondary)
                                }
                            }

                            Spacer()

                            // Reading status indicator
                            statusIcon(work.userStatus)
                        }
                        .padding(.horizontal, ShelfSpacing.lg)
                        .padding(.vertical, ShelfSpacing.sm)

                        ShelfDivider()
                            .padding(.horizontal, ShelfSpacing.lg)
                    }
                }
            }
            .padding(.top, ShelfSpacing.sm)
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: String?) -> some View {
        switch status {
        case "read":
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ShelfColors.forest)
                .accessibilityLabel("Read")
        case "reading":
            Image(systemName: "book.fill")
                .foregroundStyle(ShelfColors.ocean)
                .accessibilityLabel("Currently reading")
        case "want_to_read":
            Image(systemName: "bookmark.fill")
                .foregroundStyle(ShelfColors.amber)
                .accessibilityLabel("Want to read")
        default:
            Image(systemName: "circle")
                .foregroundStyle(ShelfColors.textTertiary)
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
