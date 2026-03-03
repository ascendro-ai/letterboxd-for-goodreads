import SwiftUI

/// Pinterest-style masonry layout for book cover grids.
/// Arranges items in 3 columns maintaining natural aspect ratios.
struct MasonryLayout: Layout {
    var columns: Int = 3
    var spacing: CGFloat = ShelfSpacing.sm

    struct CacheData {
        var sizes: [CGSize] = []
        var columns: [[CGRect]] = []
        var totalSize: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        cache = result
        return result.totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        let allRects = cache.columns.flatMap { $0 }
        let sortedRects = allRects.sorted { a, b in
            // Match original subview order
            if a.origin.y != b.origin.y { return a.origin.y < b.origin.y }
            return a.origin.x < b.origin.x
        }

        for (index, subview) in subviews.enumerated() {
            guard index < sortedRects.count else { break }
            let rect = sortedRects[index]
            subview.place(
                at: CGPoint(x: bounds.minX + rect.origin.x, y: bounds.minY + rect.origin.y),
                proposal: ProposedViewSize(width: rect.width, height: rect.height)
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> CacheData {
        let totalWidth = proposal.width ?? 300
        let columnWidth = (totalWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        var columnHeights = Array(repeating: CGFloat(0), count: columns)
        var columnRects: [[CGRect]] = Array(repeating: [], count: columns)

        for subview in subviews {
            // Find shortest column
            let shortestColumn = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0

            let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
            let itemHeight = size.height > 0 ? size.height : columnWidth * 1.5 // fallback aspect ratio

            let x = CGFloat(shortestColumn) * (columnWidth + spacing)
            let y = columnHeights[shortestColumn]

            columnRects[shortestColumn].append(CGRect(x: x, y: y, width: columnWidth, height: itemHeight))
            columnHeights[shortestColumn] = y + itemHeight + spacing
        }

        let maxHeight = columnHeights.max() ?? 0
        return CacheData(
            columns: columnRects,
            totalSize: CGSize(width: totalWidth, height: max(0, maxHeight - spacing))
        )
    }
}
