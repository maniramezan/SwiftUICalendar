import SwiftUI

struct CalendarGridLayout: Equatable {
  let width: CGFloat
  let cellSize: CGFloat
  let columns: [GridItem]

  init(containerWidth: CGFloat, metrics: CalendarMetrics) {
    width = max(containerWidth, metrics.minCalendarWidth)
    let availableCellWidth = max(0, width - (metrics.itemSpacing * 6))
    cellSize = min(
      metrics.maxCellSize,
      max(metrics.minCellSize, availableCellWidth / 7)
    )
    columns = Array(
      repeating: GridItem(
        .flexible(minimum: metrics.minCellSize),
        spacing: metrics.itemSpacing,
        alignment: .center
      ),
      count: 7
    )
  }

  static func == (lhs: CalendarGridLayout, rhs: CalendarGridLayout) -> Bool {
    lhs.width == rhs.width && lhs.cellSize == rhs.cellSize
  }
}
