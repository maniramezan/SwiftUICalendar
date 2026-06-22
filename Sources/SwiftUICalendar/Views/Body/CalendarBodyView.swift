import SwiftCommons
import SwiftUI

struct CalendarBodyView: View {
  private static let headerHeightRatio: CGFloat = 0.45
  private static let minHeaderHeight: CGFloat = 24

  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.calendarMetrics) private var metrics
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var containerWidth: CGFloat = 0
  private let displayMonth: Int?
  private let displayYear: Int?
  private let showWeekdayHeader: Bool
  private let hideOverflowDays: Bool
  /// When `true`, tapping a day outside the displayed month navigates the calendar to that month.
  /// Set to `false` for scroll modes where the adjacent month is already visible.
  private let navigatesOnOverflowTap: Bool

  private var layoutWidth: CGFloat {
    max(containerWidth, metrics.minCalendarWidth)
  }

  private var cellSize: CGFloat {
    let totalInteritemSpacing = metrics.itemSpacing * 6
    let widthForCells = max(0, layoutWidth - totalInteritemSpacing)
    let columnWidth = widthForCells / 7
    return min(metrics.maxCellSize, max(metrics.minCellSize, columnWidth))
  }

  private var headerHeight: CGFloat {
    max(Self.headerHeightRatio * cellSize, Self.minHeaderHeight)
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(
        .flexible(minimum: metrics.minCellSize), spacing: metrics.itemSpacing, alignment: .center),
      count: 7
    )
  }

  private var dayItems: [DayRenderItem] {
    let previousMonthMetadata =
      viewModel.monthMetadata(
        month: activeMonth,
        year: activeYear,
        offset: -1
      ) ?? fallbackMetadata(month: activeMonth, year: activeYear, offset: -1)
    let nextMonthMetadata =
      viewModel.monthMetadata(
        month: activeMonth,
        year: activeYear,
        offset: 1
      ) ?? fallbackMetadata(month: activeMonth, year: activeYear, offset: 1)
    let leadingEmptyDaysCount = max(
      viewModel.startOfMonthDay(month: activeMonth, year: activeYear) - 1, 0)
    let previousMonthDaysCount = previousMonthMetadata.numberOfDays
    let previousMonthStartingDay = max(1, previousMonthDaysCount - leadingEmptyDaysCount + 1)
    let totalDaysToRender =
      leadingEmptyDaysCount
      + viewModel.numberOfDaysInMonth(
        month: activeMonth,
        year: activeYear
      )
    let trailingEmptyDaysCount: Int = {
      let remainder = totalDaysToRender % 7
      return remainder == 0 ? 0 : 7 - remainder
    }()

    var items = (0..<totalDaysToRender).map { index in
      let isCurrentMonth = index >= leadingEmptyDaysCount
      let day: Int
      let dayLabel: String
      let targetMonth: Int
      let targetYear: Int
      let isToday: Bool
      let isSelected: Bool
      let date: Date?

      if isCurrentMonth {
        day = index - leadingEmptyDaysCount + 1
        targetMonth = activeMonth
        targetYear = activeYear
        date = viewModel.date(for: day, month: targetMonth, year: targetYear)
        isToday =
          date != nil && viewModel.isToday(day: day, month: targetMonth, year: targetYear)
        isSelected = date.map { viewModel.isSelected(date: $0) } ?? false
      } else {
        day = previousMonthStartingDay + index
        targetMonth = previousMonthMetadata.month
        targetYear = previousMonthMetadata.year
        date = viewModel.date(for: day, month: targetMonth, year: targetYear)
        isToday = false
        isSelected = date.map { viewModel.isSelected(date: $0) } ?? false
      }

      dayLabel = NumberFormatter.formatDay(day, locale: viewModel.locale)

      return DayRenderItem(
        id: "day-\(targetYear)-\(targetMonth)-\(day)",
        day: day,
        dayLabel: dayLabel,
        date: date,
        targetMonth: targetMonth,
        targetYear: targetYear,
        isCurrentMonth: isCurrentMonth,
        isToday: isToday,
        isSelected: isSelected
      )
    }

    if trailingEmptyDaysCount > 0 {
      let trailingItems = (0..<trailingEmptyDaysCount).map { index in
        let day = index + 1
        let dayLabel = NumberFormatter.formatDay(day, locale: viewModel.locale)
        let targetMonth = nextMonthMetadata.month
        let targetYear = nextMonthMetadata.year
        let date = viewModel.date(for: day, month: targetMonth, year: targetYear)
        return DayRenderItem(
          id: "day-\(targetYear)-\(targetMonth)-\(day)",
          day: day,
          dayLabel: dayLabel,
          date: date,
          targetMonth: targetMonth,
          targetYear: targetYear,
          isCurrentMonth: false,
          isToday: false,
          isSelected: date.map { viewModel.isSelected(date: $0) } ?? false
        )
      }
      items.append(contentsOf: trailingItems)
    }
    return items
  }

  private var rowCount: Int {
    max(1, (dayItems.count + 6) / 7)
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

  private var orderedDayItems: [DayRenderItem] {
    if !isRightToLeft {
      return dayItems
    }

    let rowWidth = 7
    var reordered: [DayRenderItem] = []
    reordered.reserveCapacity(dayItems.count)
    var index = 0

    while index < dayItems.count {
      let endIndex = min(index + rowWidth, dayItems.count)
      reordered.append(contentsOf: dayItems[index..<endIndex].reversed())
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
        .accessibilityHidden(true)
      }

      // Day cells
      LazyVGrid(
        columns: columns,
        alignment: .center,
        spacing: metrics.rowSpacing
      ) {
        ForEach(orderedDayItems) { item in
          if let date = item.date, !(hideOverflowDays && !item.isCurrentMonth) {
            let context = CalendarDayContext(
              date: date,
              day: item.day,
              dayLabel: item.dayLabel,
              isToday: item.isToday,
              isSelected: item.isSelected,
              isInCurrentMonth: item.isCurrentMonth,
              theme: theme.day,
              typography: typography,
              onSelect: { selectedDate in
                handleSelection(for: item, selectedDate: selectedDate)
              },
              secondaryLabel: resolveSecondaryLabel(for: date)
            )

            AnyView(theme.day.dayContent(context))
              .id(item.id)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .frame(height: cellSize)
              .foregroundStyle(item.isCurrentMonth ? Color.primary : Color.gray)
              .contentShape(Rectangle())
          } else {
            // Hidden overflow day, or a date that could not be resolved.
            Color.clear
              .frame(maxWidth: .infinity)
              .frame(height: cellSize)
          }
        }
      }
    }
    .frame(height: calendarHeight, alignment: .top)
    // Fill the available width; cells spread to fill while row height stays capped (see cellSize).
    .frame(maxWidth: .infinity, alignment: .top)
    .background(
      GeometryReader { geometry in
        Color.clear
          .onAppear { containerWidth = geometry.size.width }
          .onChange(of: geometry.size.width) { _, newWidth in
            containerWidth = newWidth
          }
      }
    )
  }

  init(
    displayMonth: Int? = nil, displayYear: Int? = nil, showWeekdayHeader: Bool = true,
    hideOverflowDays: Bool = false, navigatesOnOverflowTap: Bool = true
  ) {
    self.displayMonth = displayMonth
    self.displayYear = displayYear
    self.showWeekdayHeader = showWeekdayHeader
    self.hideOverflowDays = hideOverflowDays
    self.navigatesOnOverflowTap = navigatesOnOverflowTap
  }
}

private struct DayRenderItem: Identifiable {
  let id: String
  let day: Int
  let dayLabel: String
  let date: Date?
  let targetMonth: Int
  let targetYear: Int
  let isCurrentMonth: Bool
  let isToday: Bool
  let isSelected: Bool
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

  fileprivate func handleSelection(for item: DayRenderItem, selectedDate: Date) {
    // Tapping a day from an adjacent month navigates the calendar to that month — but only when
    // navigation is allowed. In a vertical scroll the target month is already on screen, so
    // mutating `currentDate` here would trigger an unwanted scroll jump.
    if navigatesOnOverflowTap, !item.isCurrentMonth {
      viewModel.currentYear = item.targetYear
      viewModel.currentMonth = item.targetMonth
    }
    viewModel.select(selectedDate)
  }

  fileprivate func fallbackMetadata(month baseMonth: Int, year baseYear: Int, offset: Int)
    -> CalendarViewModel.MonthMetadata
  {
    let monthCount = max(1, viewModel.monthSymbols.count)
    var monthIndex = (baseMonth - 1) + offset
    var year = baseYear

    while monthIndex < 0 {
      monthIndex += monthCount
      year -= 1
    }

    while monthIndex >= monthCount {
      monthIndex -= monthCount
      year += 1
    }

    let month = monthIndex + 1

    return CalendarViewModel.MonthMetadata(
      month: month,
      year: year,
      numberOfDays: viewModel.numberOfDaysInMonth(month: month, year: year)
    )
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
