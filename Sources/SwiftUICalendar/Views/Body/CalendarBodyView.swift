import SwiftCommons
import SwiftUI

struct CalendarBodyView: View {
  private static let headerHeightRatio: CGFloat = 0.45
  private static let minHeaderHeight: CGFloat = 24

  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.calendarConfiguration) private var configuration
  @Environment(\.calendarMetrics) private var metrics
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var containerWidth: CGFloat = 0
  private let layoutWidth: CGFloat?
  private let displayMonth: Int?
  private let displayYear: Int?
  private let showWeekdayHeader: Bool
  private let hideOverflowDays: Bool
  /// When `true`, tapping a day outside the displayed month navigates the calendar to that month.
  /// Set to `false` for scroll modes where the adjacent month is already visible.
  private let navigatesOnOverflowTap: Bool

  private var gridLayout: CalendarGridLayout {
    CalendarGridLayout(
      containerWidth: layoutWidth ?? containerWidth,
      metrics: metrics,
      sizing: configuration.gridSizing
    )
  }

  private var cellSize: CGFloat {
    gridLayout.cellSize
  }

  private var headerHeight: CGFloat {
    max(Self.headerHeightRatio * cellSize, Self.minHeaderHeight)
  }

  private var columns: [GridItem] {
    gridLayout.columns
  }

  private var gridWidth: CGFloat {
    gridLayout.gridWidth
  }

  private var snapshot: MonthSnapshot {
    viewModel.monthSnapshot(for: MonthIdentifier(month: activeMonth, year: activeYear))
      ?? MonthSnapshot(
        id: MonthIdentifier(month: activeMonth, year: activeYear),
        title: "",
        days: []
      )
  }

  private var rowCount: Int {
    snapshot.rowCount
  }

  private var isRightToLeft: Bool {
    layoutDirection == .rightToLeft
  }

  private var orderedHeaderTitles: [String] {
    if isRightToLeft {
      return Array(viewModel.headerTitles.reversed())
    }
    return viewModel.headerTitles
  }

  private var orderedDayItems: [MonthSnapshot.Day] {
    if !isRightToLeft {
      return snapshot.days
    }

    let rowWidth = 7
    var reordered: [MonthSnapshot.Day] = []
    reordered.reserveCapacity(snapshot.days.count)
    var index = 0

    while index < snapshot.days.count {
      let endIndex = min(index + rowWidth, snapshot.days.count)
      reordered.append(contentsOf: snapshot.days[index..<endIndex].reversed())
      index += rowWidth
    }

    return reordered
  }

  private var calendarHeight: CGFloat {
    if showWeekdayHeader {
      // Row spacings: 1 between header and days + (rowCount - 1) between day rows
      let totalRowSpacing = metrics.rowSpacing * CGFloat(rowCount)
      return headerHeight + (CGFloat(rowCount) * cellSize) + totalRowSpacing
    } else {
      // Grid only: (rowCount - 1) spacings between rows
      return CGFloat(rowCount) * cellSize + CGFloat(rowCount - 1) * metrics.rowSpacing
    }
  }

  var body: some View {
    VStack(spacing: metrics.rowSpacing) {
      // Weekday headers
      if showWeekdayHeader {
        LazyVGrid(columns: columns, alignment: .center, spacing: 0) {
          ForEach(Array(orderedHeaderTitles.enumerated()), id: \.offset) { _, day in
            Text(day)
              .font(typography.weekdayHeaderFont)
              .lineLimit(1)
              .minimumScaleFactor(typography.minScaleFactor ?? 1.0)
              .frame(height: headerHeight)
              .frame(maxWidth: .infinity)
          }
        }
        .frame(width: gridWidth)
        .accessibilityHidden(true)
      }

      // Day cells
      LazyVGrid(
        columns: columns,
        alignment: .center,
        spacing: metrics.rowSpacing
      ) {
        ForEach(orderedDayItems) { item in
          if let date = item.date, !(hideOverflowDays && !item.isInDisplayedMonth) {
            let context = CalendarDayContext(
              date: date,
              day: item.day,
              dayLabel: item.dayLabel,
              isToday: item.isToday,
              isSelected: item.isSelected,
              isInCurrentMonth: item.isInDisplayedMonth,
              theme: theme.day,
              typography: typography,
              onSelect: { selectedDate in
                handleSelection(for: item, selectedDate: selectedDate)
              },
              secondaryLabel: resolveSecondaryLabel(for: date)
            )

            CalendarDayCell(context: context, renderer: theme.day.renderer)
              .id(item.id)
              // Keep the cell a square (cellSize × cellSize) and center it in the wider column so
              // square day views stay square when the grid fills a wide window.
              .frame(width: cellSize, height: cellSize)
              .frame(maxWidth: .infinity)
              .foregroundStyle(item.isInDisplayedMonth ? Color.primary : Color.gray)
              .contentShape(Rectangle())
          } else {
            // Hidden overflow day, or a date that could not be resolved.
            Color.clear
              .frame(maxWidth: .infinity)
              .frame(height: cellSize)
          }
        }
      }
      .frame(width: gridWidth)
    }
    .frame(height: calendarHeight, alignment: .top)
    // The containing frame keeps the grid centered when its configured sizing is compact.
    .frame(maxWidth: .infinity, alignment: .top)
    .onGeometryChange(for: CGFloat.self) { geometry in geometry.size.width } action: { width in
      guard layoutWidth == nil, containerWidth != width else { return }
      containerWidth = width
    }
  }

  init(
    displayMonth: Int? = nil, displayYear: Int? = nil, showWeekdayHeader: Bool = true,
    hideOverflowDays: Bool = false, navigatesOnOverflowTap: Bool = true, layoutWidth: CGFloat? = nil
  ) {
    self.displayMonth = displayMonth
    self.displayYear = displayYear
    self.showWeekdayHeader = showWeekdayHeader
    self.hideOverflowDays = hideOverflowDays
    self.navigatesOnOverflowTap = navigatesOnOverflowTap
    self.layoutWidth = layoutWidth
  }
}

private struct CalendarDayCell: View {
  let context: CalendarDayContext
  let renderer: Theme.Day.Renderer

  var body: some View {
    switch renderer {
    case .circle:
      CircleDayView(context: context)
    case .square:
      SquareDualCalendarDayView(context: context)
    case .custom(let content):
      content(context)
    }
  }
}

extension CalendarBodyView {
  fileprivate var activeMonth: Int {
    displayMonth ?? viewModel.currentMonth
  }

  fileprivate var activeYear: Int {
    displayYear ?? viewModel.currentYear
  }

  /// Resolves the secondary label for a date using the configured label mode.
  fileprivate func resolveSecondaryLabel(for date: Date) -> String? {
    return theme.day.secondaryLabelMode.label(for: date)
  }

  fileprivate func handleSelection(for item: MonthSnapshot.Day, selectedDate: Date) {
    // Tapping a day from an adjacent month navigates the calendar to that month — but only when
    // navigation is allowed. In a vertical scroll the target month is already on screen, so
    // mutating `currentDate` here would trigger an unwanted scroll jump.
    if navigatesOnOverflowTap, !item.isInDisplayedMonth {
      if let targetDate = viewModel.firstDate(month: item.month, year: item.year) {
        try? viewModel.navigate(to: targetDate)
      }
    }
    viewModel.select(selectedDate)
  }

}

#Preview("Persian: Range") {
  CalendarBodyView()
    .environment(
      CalendarViewModel.test(
        identifier: .persian,
        selection: .range(nil, nil))
    )
    .environment(Theme.default)
    .environment(Typography.default)
}
