import SwiftUI

/// Small badge shown below a book title indicating its position in a series.
/// Tapping navigates to the series detail view.
struct SeriesBadge: View {
    let series: Series
    let position: Double

    var body: some View {
        NavigationLink {
            SeriesDetailView(seriesID: series.id, seriesName: series.name)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "books.vertical")
                    .font(.caption2)
                Text("Book \(positionText) of \(series.name)")
                    .font(.caption)
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Book \(positionText) of the series \(series.name). Tap to view series.")
    }

    private var positionText: String {
        position.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", position)
            : String(format: "%.1f", position)
    }
}
