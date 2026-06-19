import SwiftCommons
import SwiftUI

struct CalendarBodyView: View {
  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.layoutDirection) private var layoutDirection
  @State private var containerWidth: CGFloat = 0
  private let displayMonth: Int?
  private let displayYear: Int?
  private let showWeekdayHeader: Bool
  private let hideOverflowDays: Bool
  /// When `true`, tapping a day outside the displayed month navigates the calendar to that month.
  /// Set to `false` for scroll modes where the adjacent month is already visible.
  private let navigatesOnOverflowTap: Bool

  private var metrics: CalendarGridMetrics {
    CalendarGridMetrics(containerWidth: containerWidth)
  }

  private var monthLayout: MonthGridLayout {
    MonthGridLayout(
      startOfMonthDay: viewModel.startOfMonthDay(month: activeMonth, year: activeYear),
      currentMonthDays: viewModel.numberOfDaysInMonth(month: activeMonth, year: activeYear),
      previousMonthDays: previousMonthMetadata.numberOfDays
    )
  }

  private var previousMonthMetadata: CalendarViewModel.MonthMetadata {
    viewModel.monthMetadata(month: activeMonth, year: activeYear, offset: -1)
      ?? fallbackMetadata(month: activeMonth, year: activeYear, offset: -1)
  }

  private var nextMonthMetadata: CalendarViewModel.MonthMetadata {
    viewModel.monthMetadata(month: activeMonth, year: activeYear, offset: 1)
      ?? fallbackMetadata(month: activeMonth, year: activeYear, offset: 1)
  }

  private var dayItems: [DayRenderItem] {
    let layout = monthLayout
    var items = leadingAndCurrentItems(layout: layout, previousMonth: previousMonthMetadata)
    items.append(contentsOf: trailingItems(layout: layout, nextMonth: nextMonthMetadata))
    return items
  }

  private var rowCount: Int {
    monthLayout.rowCount
  }

  private var isRightToLeft: Bool {
    layoutDirection == .rightToLeft
  }

  private var orderedHeaderTitles: [String] {
    isRightToLeft ? Array(viewModel.headerTitles.reversed()) : viewModel.headerTitles
  }

  private var orderedDayItems: [DayRenderItem] {
    isRightToLeft ? MonthGridLayout.rowReversed(dayItems) : dayItems
  }

  private var calendarHeight: CGFloat {
    showWeekdayHeader
      ? metrics.contentHeight(rowCount: rowCount)
      : metrics.gridHeight(rowCount: rowCount)
  }

  var body: some View {
    VStack(spacing: CalendarGridMetrics.rowSpacing) {
      if showWeekdayHeader {
        WeekdayHeaderRow(
          titles: orderedHeaderTitles,
          height: metrics.weekdayHeaderHeight,
          font: typography.weekdayHeaderFont,
          minScaleFactor: typography.minScaleFactor ?? 1.0
        )
      }

      // Day cells
      LazyVGrid(
        columns: CalendarGridMetrics.columns,
        alignment: .center,
        spacing: CalendarGridMetrics.rowSpacing
      ) {
        ForEach(orderedDayItems) { item in
          dayCell(for: item)
        }
      }
    }
    .frame(height: calendarHeight, alignment: .top)
    .frame(maxWidth: .infinity, alignment: .top)
    .measuringContainerWidth($containerWidth)
  }

  @ViewBuilder
  private func dayCell(for item: DayRenderItem) -> some View {
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
        .frame(height: metrics.cellSize)
        .foregroundStyle(item.isCurrentMonth ? Color.primary : Color.gray)
        .contentShape(Rectangle())
    } else {
      // Hidden overflow day, or a date that could not be resolved.
      Color.clear
        .frame(maxWidth: .infinity)
        .frame(height: metrics.cellSize)
    }
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

  /// Leading previous-month cells followed by the current month's days.
  fileprivate func leadingAndCurrentItems(
    layout: MonthGridLayout, previousMonth: CalendarViewModel.MonthMetadata
  ) -> [DayRenderItem] {
    (0..<layout.leadingAndCurrentCount).map { index in
      let isCurrentMonth = index >= layout.leadingEmptyDays
      if isCurrentMonth {
        let day = index - layout.leadingEmptyDays + 1
        return makeDayItem(
          day: day, month: activeMonth, year: activeYear,
          isCurrentMonth: true, checksToday: true)
      } else {
        let day = layout.previousMonthStartingDay + index
        return makeDayItem(
          day: day, month: previousMonth.month, year: previousMonth.year,
          isCurrentMonth: false, checksToday: false)
      }
    }
  }

  /// Trailing next-month cells that pad the final row.
  fileprivate func trailingItems(
    layout: MonthGridLayout, nextMonth: CalendarViewModel.MonthMetadata
  ) -> [DayRenderItem] {
    guard layout.trailingEmptyDays > 0 else { return [] }
    return (0..<layout.trailingEmptyDays).map { index in
      makeDayItem(
        day: index + 1, month: nextMonth.month, year: nextMonth.year,
        isCurrentMonth: false, checksToday: false)
    }
  }

  fileprivate func makeDayItem(
    day: Int, month: Int, year: Int, isCurrentMonth: Bool, checksToday: Bool
  ) -> DayRenderItem {
    let date = viewModel.date(for: day, month: month, year: year)
    let isToday = checksToday && date != nil && viewModel.isToday(day: day, month: month, year: year)
    return DayRenderItem(
      id: "day-\(year)-\(month)-\(day)",
      day: day,
      dayLabel: NumberFormatter.formatDay(day, locale: viewModel.locale),
      date: date,
      targetMonth: month,
      targetYear: year,
      isCurrentMonth: isCurrentMonth,
      isToday: isToday,
      isSelected: date.map { viewModel.isSelected(date: $0) } ?? false
    )
  }

  /// Resolves the secondary label for a date using the configured label mode.
  fileprivate func resolveSecondaryLabel(for date: Date) -> String? {
    theme.day.secondaryLabelMode.label(for: date)
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

  /// Synthesizes adjacent-month metadata by wrapping month indices when the view model cannot
  /// resolve a real date (e.g. at the supported-year edges). Year rolls over as months wrap.
  fileprivate func fallbackMetadata(month baseMonth: Int, year baseYear: Int, offset: Int)
    -> CalendarViewModel.MonthMetadata
  {
    let monthCount = max(1, viewModel.monthSymbols.count)
    let wrapped = MonthGridLayout.wrappedMonth(
      base: baseMonth, offset: offset, monthCount: monthCount)
    let month = wrapped.month
    let year = baseYear + wrapped.yearDelta

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
