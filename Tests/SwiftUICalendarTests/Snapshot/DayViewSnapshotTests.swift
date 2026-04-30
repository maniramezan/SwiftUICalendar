import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Day View Snapshot Tests")
struct DayViewSnapshotTests {

  // Pinned date for context: June 15, 2025
  private let pinnedDate = Calendar(identifier: .gregorian)
    .date(from: DateComponents(year: 2025, month: 6, day: 15))!

  private func makeContext(
    day: Int = 15,
    dayLabel: String = "15",
    isToday: Bool = false,
    isSelected: Bool = false,
    isInCurrentMonth: Bool = true,
    secondaryLabel: String? = nil,
    theme: Theme.Day = Theme().day
  ) -> CalendarDayContext {
    CalendarDayContext(
      date: pinnedDate,
      day: day,
      dayLabel: dayLabel,
      isToday: isToday,
      isSelected: isSelected,
      isInCurrentMonth: isInCurrentMonth,
      theme: theme,
      typography: Typography.default,
      onSelect: { _ in },
      secondaryLabel: secondaryLabel
    )
  }

  // MARK: - CircleDayView

  @Test("CircleDayView: normal state")
  func circleDayNormal() {
    let view = CircleDayView(context: makeContext())
      .frame(width: 44, height: 44)
    assertCalendarSnapshot(of: view, width: 44, height: 44, named: "circle-normal")
  }

  @Test("CircleDayView: today state")
  func circleDayToday() {
    let view = CircleDayView(context: makeContext(isToday: true))
      .frame(width: 44, height: 44)
    assertCalendarSnapshot(of: view, width: 44, height: 44, named: "circle-today")
  }

  @Test("CircleDayView: selected state")
  func circleDaySelected() {
    let view = CircleDayView(context: makeContext(isSelected: true))
      .frame(width: 44, height: 44)
    assertCalendarSnapshot(of: view, width: 44, height: 44, named: "circle-selected")
  }

  @Test("CircleDayView: today and selected")
  func circleDayTodayAndSelected() {
    let view = CircleDayView(context: makeContext(isToday: true, isSelected: true))
      .frame(width: 44, height: 44)
    assertCalendarSnapshot(of: view, width: 44, height: 44, named: "circle-today-selected")
  }

  @Test("CircleDayView: out-of-month state")
  func circleDayOutOfMonth() {
    let view = CircleDayView(context: makeContext(isInCurrentMonth: false))
      .frame(width: 44, height: 44)
      .foregroundStyle(Color.gray)
    assertCalendarSnapshot(of: view, width: 44, height: 44, named: "circle-out-of-month")
  }

  // MARK: - SquareDualCalendarDayView

  @Test("SquareDualCalendarDayView: normal state")
  func squareDayNormal() {
    let view = SquareDualCalendarDayView(context: makeContext())
      .frame(width: 50, height: 50)
    assertCalendarSnapshot(of: view, width: 50, height: 50, named: "square-normal")
  }

  @Test("SquareDualCalendarDayView: with Persian secondary label")
  func squareDayWithPersianSecondaryLabel() {
    let persianLabel = Theme.Day.SecondaryLabelMode.persian.label(for: pinnedDate)
    let view = SquareDualCalendarDayView(
      context: makeContext(secondaryLabel: persianLabel)
    )
    .frame(width: 50, height: 50)
    assertCalendarSnapshot(of: view, width: 50, height: 50, named: "square-persian-label")
  }

  @Test("SquareDualCalendarDayView: today state")
  func squareDayToday() {
    let view = SquareDualCalendarDayView(context: makeContext(isToday: true))
      .frame(width: 50, height: 50)
    assertCalendarSnapshot(of: view, width: 50, height: 50, named: "square-today")
  }

  @Test("SquareDualCalendarDayView: selected state")
  func squareDaySelected() {
    let view = SquareDualCalendarDayView(context: makeContext(isSelected: true))
      .frame(width: 50, height: 50)
    assertCalendarSnapshot(of: view, width: 50, height: 50, named: "square-selected")
  }

  @Test("SquareDualCalendarDayView: out-of-month border state")
  func squareDayOutOfMonthBorder() {
    let theme = Theme()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1

    let view = SquareDualCalendarDayView(
      context: makeContext(isInCurrentMonth: false, theme: theme.day)
    )
    .frame(width: 50, height: 50)

    assertCalendarSnapshot(of: view, width: 50, height: 50, named: "square-out-of-month-border")
  }
}
