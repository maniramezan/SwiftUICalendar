import SwiftUI

struct CalendarGridLayout: Equatable {
  let width: CGFloat
  let cellSize: CGFloat
  let gridWidth: CGFloat
  let columns: [GridItem]

  init(
    containerWidth: CGFloat,
    metrics: CalendarMetrics,
    sizing: CalendarConfiguration.GridSizing = .adaptive
  ) {
    width = max(containerWidth, metrics.minCalendarWidth)
    let availableCellWidth = max(0, width - (metrics.itemSpacing * 6))
    cellSize = min(
      metrics.maxCellSize,
      max(metrics.minCellSize, availableCellWidth / 7)
    )
    let naturalGridWidth = (cellSize * 7) + (metrics.itemSpacing * 6)
    let usesCompactWidth = switch sizing {
    case .compact:
      true
    case .flexible:
      false
    case .adaptive:
      cellSize == metrics.maxCellSize
    }
    gridWidth = usesCompactWidth ? naturalGridWidth : width
    columns = Array(
      repeating: GridItem(
        usesCompactWidth ? .fixed(cellSize) : .flexible(minimum: metrics.minCellSize),
        spacing: metrics.itemSpacing,
        alignment: .center
      ),
      count: 7
    )
  }

  static func == (lhs: CalendarGridLayout, rhs: CalendarGridLayout) -> Bool {
    lhs.width == rhs.width && lhs.cellSize == rhs.cellSize && lhs.gridWidth == rhs.gridWidth
  }
}
