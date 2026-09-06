import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Day cell structural snapshots", .enabled(if: snapshotsEnabled))
struct DayViewSnapshotTests {

  // Pinned date for context: June 15, 2025
  private let pinnedDate = Calendar(identifier: .gregorian)
    .date(from: DateComponents(year: 2025, month: 6, day: 15))!

  private func circleTheme() -> Theme { Theme() }

  private func squareTheme(secondaryLabel: Theme.Day.SecondaryLabelMode? = nil) -> Theme {
    let theme = Theme()
    theme.day.useSquareDualCalendarDayView(secondaryLabel: secondaryLabel)
    return theme
  }

  private func makeContext(
    dayLabel: String = "15",
    isToday: Bool = false,
    isSelected: Bool = false,
    isInCurrentMonth: Bool = true,
    secondaryLabel: String? = nil,
    theme: Theme.Day
  ) -> CalendarDayContext {
    CalendarDayContext(
      date: pinnedDate,
      day: 15,
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

  // MARK: - Circle renderer

  @Test("Circle day: normal state")
  func circleDayNormal() {
    let theme = circleTheme()
    assertDayContextStructure(
      makeContext(theme: theme.day), rendererFor: theme, named: "circle-normal")
  }

  @Test("Circle day: today state")
  func circleDayToday() {
    let theme = circleTheme()
    assertDayContextStructure(
      makeContext(isToday: true, theme: theme.day), rendererFor: theme, named: "circle-today")
  }

  @Test("Circle day: selected state")
  func circleDaySelected() {
    let theme = circleTheme()
    assertDayContextStructure(
      makeContext(isSelected: true, theme: theme.day), rendererFor: theme, named: "circle-selected")
  }

  @Test("Circle day: today and selected")
  func circleDayTodayAndSelected() {
    let theme = circleTheme()
    assertDayContextStructure(
      makeContext(isToday: true, isSelected: true, theme: theme.day),
      rendererFor: theme, named: "circle-today-selected")
  }

  @Test("Circle day: out-of-month state")
  func circleDayOutOfMonth() {
    let theme = circleTheme()
    assertDayContextStructure(
      makeContext(isInCurrentMonth: false, theme: theme.day),
      rendererFor: theme, named: "circle-out-of-month")
  }

  // MARK: - Square dual renderer

  @Test("Square day: normal state")
  func squareDayNormal() {
    let theme = squareTheme()
    assertDayContextStructure(
      makeContext(theme: theme.day), rendererFor: theme, named: "square-normal")
  }

  @Test("Square day: with Persian secondary label")
  func squareDayWithPersianSecondaryLabel() {
    let theme = squareTheme(secondaryLabel: .persian)
    let persianLabel = Theme.Day.SecondaryLabelMode.persian.label(for: pinnedDate)
    assertDayContextStructure(
      makeContext(secondaryLabel: persianLabel, theme: theme.day),
      rendererFor: theme, named: "square-persian-label")
  }

  @Test("Square day: today state")
  func squareDayToday() {
    let theme = squareTheme()
    assertDayContextStructure(
      makeContext(isToday: true, theme: theme.day), rendererFor: theme, named: "square-today")
  }

  @Test("Square day: selected state")
  func squareDaySelected() {
    let theme = squareTheme()
    assertDayContextStructure(
      makeContext(isSelected: true, theme: theme.day), rendererFor: theme, named: "square-selected")
  }

  @Test("Square day: out-of-month border state")
  func squareDayOutOfMonthBorder() {
    let theme = squareTheme()
    theme.day.emptyDayBorderColor = .pink
    theme.day.emptyDayBorderColorWidth = 1
    assertDayContextStructure(
      makeContext(isInCurrentMonth: false, theme: theme.day),
      rendererFor: theme, named: "square-out-of-month-border")
  }
}
