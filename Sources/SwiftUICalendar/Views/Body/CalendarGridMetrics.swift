import SwiftUI

/// Shared sizing math for the 7-column calendar grid.
///
/// Both the fixed/vertical body (`CalendarBodyView`) and the horizontal carousel
/// (`CalendarBodyHorizontalView`) lay out an identical week grid, so the spacing constants and
/// the width-to-cell-size derivation live here to avoid drift between the two layouts.
struct CalendarGridMetrics {
  static let columnCount = 7
  static let itemSpacing: CGFloat = 8
  static let rowSpacing: CGFloat = 10
  static let minCellSize: CGFloat = SizingClass.Day.minimumWidth
  static let headerHeightRatio: CGFloat = 0.45
  static let minHeaderHeight: CGFloat = 24

  /// Extra padding added to a ceil-rounded height so sub-pixel grid content never clips.
  static let heightCeilingPadding: CGFloat = 2

  /// The smallest width that still fits seven minimum-size cells plus their interitem spacing.
  static var minCalendarWidth: CGFloat {
    (CGFloat(columnCount) * minCellSize) + (CGFloat(columnCount - 1) * itemSpacing)
  }

  /// Seven flexible columns, shared by the weekday header and the day grid.
  static var columns: [GridItem] {
    Array(
      repeating: GridItem(
        .flexible(minimum: minCellSize), spacing: itemSpacing, alignment: .center),
      count: columnCount
    )
  }

  /// The measured container width; clamped to `minCalendarWidth` via ``layoutWidth``.
  let containerWidth: CGFloat

  init(containerWidth: CGFloat) {
    self.containerWidth = containerWidth
  }

  var layoutWidth: CGFloat {
    max(containerWidth, Self.minCalendarWidth)
  }

  var cellSize: CGFloat {
    let totalInteritemSpacing = Self.itemSpacing * CGFloat(Self.columnCount - 1)
    let widthForCells = max(0, layoutWidth - totalInteritemSpacing)
    let columnWidth = widthForCells / CGFloat(Self.columnCount)
    return max(Self.minCellSize, columnWidth)
  }

  var weekdayHeaderHeight: CGFloat {
    max(Self.headerHeightRatio * cellSize, Self.minHeaderHeight)
  }

  /// Height of `rowCount` day rows with no weekday header (`rowCount - 1` inter-row gaps).
  func gridHeight(rowCount: Int) -> CGFloat {
    (CGFloat(rowCount) * cellSize) + (CGFloat(rowCount - 1) * Self.rowSpacing)
  }

  /// Total body height including the weekday header and its trailing gap.
  func contentHeight(rowCount: Int) -> CGFloat {
    // Row gaps: 1 between header and first day row + (rowCount - 1) between day rows.
    weekdayHeaderHeight + (CGFloat(rowCount) * cellSize) + (Self.rowSpacing * CGFloat(rowCount))
  }

  /// Ceil-rounded grid height with ceiling padding, used by the horizontal carousel where the
  /// grid scrolls independently of a static header.
  func paddedGridHeight(rowCount: Int) -> CGFloat {
    ceil(gridHeight(rowCount: rowCount)) + Self.heightCeilingPadding
  }
}

/// The static weekday header row (e.g. "S M T W T F S"), shared across calendar body layouts.
struct WeekdayHeaderRow: View {
  let titles: [String]
  let height: CGFloat
  let font: Font
  let minScaleFactor: CGFloat

  var body: some View {
    LazyVGrid(columns: CalendarGridMetrics.columns, alignment: .center, spacing: 0) {
      ForEach(Array(titles.enumerated()), id: \.offset) { _, day in
        Text(day)
          .font(font)
          .lineLimit(1)
          .minimumScaleFactor(minScaleFactor)
          .frame(height: height)
          .frame(maxWidth: .infinity)
      }
    }
    .accessibilityHidden(true)
  }
}

extension View {
  /// Reports the receiver's container width into `width`, updating on resize.
  func measuringContainerWidth(_ width: Binding<CGFloat>) -> some View {
    background(
      GeometryReader { geometry in
        Color.clear
          .onAppear { width.wrappedValue = geometry.size.width }
          .onChange(of: geometry.size.width) { _, newWidth in
            width.wrappedValue = newWidth
          }
      }
    )
  }
}
