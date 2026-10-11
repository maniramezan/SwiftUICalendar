import SwiftUI

/// Resolved geometry of a month grid: its width, day cell size, and the `GridItem` columns.
///
/// Pure value math — it reads `CalendarMetrics` and the grid's structural constants and holds no
/// view state, so a view can build one per layout pass and a test can assert on it directly.
struct CalendarGridLayout: Equatable {
    let width: CGFloat
    /// Width of a day cell, which is also the height at the default text size.
    let cellSize: CGFloat
    /// Height of a day row: the cell width, grown to `minRowHeight` so Dynamic Type grows rows, not columns.
    let rowHeight: CGFloat
    let gridWidth: CGFloat
    let columns: [GridItem]

    init(
        containerWidth: CGFloat,
        metrics: CalendarMetrics,
        sizing: CalendarConfiguration.GridSizing = .adaptive
    ) {
        width = max(containerWidth, metrics.minCalendarWidth)
        let cellSize = Self.cellSize(containerWidth: containerWidth, metrics: metrics)
        let naturalGridWidth =
            (cellSize * CalendarGrid.columnWidthDivisor)
            + (metrics.itemSpacing * CalendarGrid.columnGapCount)
        let usesCompactWidth =
            switch sizing {
            case .compact:
                true
            case .flexible:
                false
            case .adaptive:
                cellSize == metrics.maxCellSize
            }
        gridWidth = usesCompactWidth ? naturalGridWidth : width
        self.cellSize = cellSize
        rowHeight = max(metrics.minRowHeight, cellSize)
        columns = Array(
            repeating: GridItem(
                usesCompactWidth ? .fixed(cellSize) : .flexible(minimum: metrics.minCellSize),
                spacing: metrics.itemSpacing,
                alignment: .center
            ),
            count: CalendarGrid.columnCount
        )
    }

    /// Side length of a day cell at `containerWidth`, clamped between the metrics' bounds.
    ///
    /// Separated from ``init(containerWidth:metrics:sizing:)`` because the horizontal pager needs a
    /// cell size at a *different* width than the one it lays out — it sizes the peek it reserves at
    /// the container edge, not at the page width. One formula, so the two cannot disagree.
    static func cellSize(containerWidth: CGFloat, metrics: CalendarMetrics) -> CGFloat {
        let width = max(containerWidth, metrics.minCalendarWidth)
        let totalInteritemSpacing = metrics.itemSpacing * CalendarGrid.columnGapCount
        let widthForCells = max(0, width - totalInteritemSpacing)
        let columnWidth = widthForCells / CalendarGrid.columnWidthDivisor
        return min(metrics.maxCellSize, max(metrics.minCellSize, columnWidth))
    }

    static func == (lhs: CalendarGridLayout, rhs: CalendarGridLayout) -> Bool {
        lhs.width == rhs.width && lhs.cellSize == rhs.cellSize && lhs.rowHeight == rhs.rowHeight
            && lhs.gridWidth == rhs.gridWidth
    }
}
