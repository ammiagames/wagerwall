import SwiftUI

/// A simple line-wrapping `Layout` that places subviews left-to-right and
/// wraps to a new row when the next subview wouldn't fit.
///
/// Used by `FillInBlankView` to render an inline mix of text words, blanks,
/// and word-bank chips that wrap naturally as a paragraph.
///
/// Named `QuizFlowLayout` to avoid colliding with an existing private
/// `FlowLayout` in `LogUrgeView`.
struct QuizFlowLayout: Layout {

    enum HAlign { case leading, center, trailing }

    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 8
    var alignment: HAlign = .leading

    struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var totalWidth: CGFloat = 0
        var maxHeight: CGFloat = 0
    }

    struct LayoutCache {
        var rows: [Row] = []
        var totalSize: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> LayoutCache {
        LayoutCache()
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout LayoutCache) -> CGSize {
        let maxWidth = proposal.replacingUnspecifiedDimensions().width
        var rows: [Row] = [Row()]

        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let leadingGap = rows[rows.count - 1].indices.isEmpty ? 0 : horizontalSpacing

            if rows[rows.count - 1].totalWidth + leadingGap + size.width > maxWidth
                && !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }

            var current = rows[rows.count - 1]
            let gap = current.indices.isEmpty ? 0 : horizontalSpacing
            current.indices.append(i)
            current.sizes.append(size)
            current.totalWidth += gap + size.width
            current.maxHeight = max(current.maxHeight, size.height)
            rows[rows.count - 1] = current
        }

        let totalHeight = rows.reduce(0) { $0 + $1.maxHeight }
            + CGFloat(max(0, rows.count - 1)) * verticalSpacing

        cache.rows = rows
        cache.totalSize = CGSize(width: maxWidth, height: totalHeight)
        return cache.totalSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout LayoutCache) {
        var y = bounds.minY

        for row in cache.rows {
            let rowSpacing = horizontalSpacing * CGFloat(max(0, row.indices.count - 1))
            let contentWidth = row.sizes.map(\.width).reduce(0, +) + rowSpacing
            var x: CGFloat
            switch alignment {
            case .leading: x = bounds.minX
            case .center:  x = bounds.minX + (bounds.width - contentWidth) / 2
            case .trailing: x = bounds.maxX - contentWidth
            }

            for (idx, originalIndex) in row.indices.enumerated() {
                let size = row.sizes[idx]
                let yOffset = y + (row.maxHeight - size.height) / 2
                subviews[originalIndex].place(
                    at: CGPoint(x: x, y: yOffset),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.maxHeight + verticalSpacing
        }
    }
}
