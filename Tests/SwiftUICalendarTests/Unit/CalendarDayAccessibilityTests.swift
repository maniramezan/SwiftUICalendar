import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar day accessibility")
struct CalendarDayAccessibilityTests {
  @Test("Spoken dates use the supplied calendar even with an English locale")
  func spokenCalendar() throws {
    let date = try #require(
      Calendar(identifier: .gregorian).date(from: DateComponents(year: 2025, month: 6, day: 15)))
    var calendar = Calendar(identifier: .persian)
    calendar.locale = Locale(identifier: "en_US")
    let context = CalendarDayContext(
      date: date, day: 25, dayLabel: "25", isToday: true,
      isSelected: true, isInCurrentMonth: true, theme: Theme().day, typography: .default,
      onSelect: { _ in }, secondaryLabel: "15", calendar: calendar)
    #expect(context.accessibilityLabel.contains("1404"))
    #expect(context.accessibilityLabel.contains("2025") == false)
    #expect(context.accessibilityLabel.contains("Today"))
    #expect(context.accessibilityLabel.contains("Selected"))
    #expect(context.accessibilityLabel.contains("Secondary 15"))
  }

  @Test("Unselected ordinary days omit status and secondary descriptions")
  func ordinaryDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US")
    let context = CalendarDayContext(
      date: Date(timeIntervalSince1970: 0), day: 1, dayLabel: "1",
      isToday: false, isSelected: false, isInCurrentMonth: true, theme: Theme().day,
      typography: .default, onSelect: { _ in }, calendar: calendar)
    #expect(context.accessibilityLabel.isEmpty == false)
    #expect(context.accessibilityLabel.contains("Selected") == false)
    #expect(context.accessibilityLabel.contains("Secondary") == false)
  }
}
