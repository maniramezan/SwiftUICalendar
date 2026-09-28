import SwiftUICalendarAccessibility
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Shared accessibility contracts")
struct CalendarAccessibilityIDTests {
    @Test(
        "Scroll modes use the same type in configuration and automation",
        arguments: CalendarScrollMode.allCases)
    func scrollModes(mode: CalendarScrollMode) {
        let configuration = CalendarConfiguration(scrollMode: mode)
        #expect(configuration.scrollMode == mode)
        #expect(mode.accessibilityIdentifier.hasPrefix("scroll-mode-"))
        #expect(CalendarScrollMode(rawValue: mode.rawValue) == mode)
    }

    @Test("Unknown scroll modes cannot be constructed")
    func unknownScrollMode() {
        #expect(CalendarScrollMode(rawValue: "Horizontal") == nil)
        #expect(CalendarScrollMode(rawValue: "") == nil)
    }

    @Test("Control identifiers are unique")
    func uniqueControls() {
        let identifiers =
            [
                CalendarSampleAccessibilityID.settings, CalendarSampleAccessibilityID.done,
                CalendarSampleAccessibilityID.scrollModePicker,
                CalendarSampleAccessibilityID.stateOwnerPicker,
            ] + CalendarScrollMode.allCases.map(\.accessibilityIdentifier)
            + SampleArchitecture.allCases.map(\.accessibilityIdentifier)
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test(
        "Month headers round trip including calendars with thirteen months",
        arguments: [1, 6, 12, 13])
    func monthHeaders(month: Int) throws {
        let identifier = CalendarAccessibilityID.verticalMonthHeader(year: 2025, month: month)
        let parsed = try #require(CalendarAccessibilityID.parseVerticalMonthHeader(identifier))
        #expect(parsed.year == 2025)
        #expect(parsed.month == month)
    }

    @Test(
        "Malformed headers are rejected",
        arguments: [
            "", "other-2025-6", "vertical-month-header-2025", "vertical-month-header-year-6",
            "vertical-month-header-2025-0", "vertical-month-header-2025-14",
            "vertical-month-header-2025-6-extra", "vertical-month-header-0-6",
        ])
    func malformedHeaders(identifier: String) {
        #expect(CalendarAccessibilityID.parseVerticalMonthHeader(identifier) == nil)
    }

    @Test("Day queries cannot confuse month or year prefixes")
    func dayPrefixes() {
        let day = CalendarAccessibilityID.day(year: 2025, month: 1, day: 1)
        #expect(day.hasPrefix(CalendarAccessibilityID.dayPrefix))
        #expect(day.hasPrefix(CalendarAccessibilityID.dayYearPrefix(year: 2025)))
        #expect(day.hasPrefix(CalendarAccessibilityID.dayMonthPrefix(year: 2025, month: 1)))
        #expect(!day.hasPrefix(CalendarAccessibilityID.dayMonthPrefix(year: 2025, month: 11)))
        #expect(!day.hasPrefix(CalendarAccessibilityID.dayYearPrefix(year: 202)))
        #expect(day != CalendarAccessibilityID.day(year: 2025, month: 1, day: 11))
    }
}
