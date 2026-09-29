import Foundation
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

    @Test(
        "Horizontal height modes use the same type in configuration and automation",
        arguments: CalendarHorizontalHeightMode.allCases)
    func horizontalHeightModes(mode: CalendarHorizontalHeightMode) {
        let configuration = CalendarConfiguration(horizontalHeightMode: mode)
        #expect(configuration.horizontalHeightMode == mode)
        #expect(CalendarConfiguration.HorizontalHeightMode.hugContent == .hugContent)
        #expect(mode.accessibilityIdentifier == "horizontal-height-\(mode.rawValue.lowercased())")
    }

    @Test(
        "Control identifiers are unique",
        arguments: [
            Calendar.Identifier.gregorian, .persian,
        ])
    func uniqueControls(calendar: Calendar.Identifier) {
        let identifiers =
            Self.allIdentifiers + [
                CalendarSampleAccessibilityID.calendarOption(calendar)
            ]
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test(
        "Calendar options cannot be confused with the calendar's own day cells",
        arguments: [Calendar.Identifier.gregorian, .persian, .buddhist, .hebrew])
    func calendarOptions(identifier: Calendar.Identifier) {
        let option = CalendarSampleAccessibilityID.calendarOption(identifier)
        #expect(option.hasPrefix("calendar-option-"))
        #expect(option != CalendarSampleAccessibilityID.calendarPicker)
        #expect(!option.hasPrefix(CalendarAccessibilityID.dayPrefix))
    }

    @Test("Year options key off the year alone", arguments: [1900, 2025, 2100])
    func yearOptions(year: Int) {
        let option = CalendarAccessibilityID.yearOption(year: year)
        #expect(option.hasPrefix(CalendarAccessibilityID.yearOptionPrefix))
        #expect(option == "\(CalendarAccessibilityID.yearOptionPrefix)\(year)")
        #expect(option != CalendarAccessibilityID.yearButton)
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

    /// Every identifier the package can emit, so a rename that collides with a sibling control
    /// fails here rather than in a UI test that can no longer tell the two apart.
    private static let allIdentifiers: [String] =
        [
            CalendarAccessibilityID.monthButton,
            CalendarAccessibilityID.previousMonthButton,
            CalendarAccessibilityID.nextMonthButton,
            CalendarAccessibilityID.yearButton,
            CalendarAccessibilityID.previousYearButton,
            CalendarAccessibilityID.nextYearButton,
            CalendarAccessibilityID.todayButton,
            CalendarAccessibilityID.yearPagePreviousButton,
            CalendarAccessibilityID.yearPageNextButton,
            CalendarAccessibilityID.yearPickerDoneButton,
            CalendarSampleAccessibilityID.settings,
            CalendarSampleAccessibilityID.done,
            CalendarSampleAccessibilityID.stateOwnerPicker,
            CalendarSampleAccessibilityID.calendarPicker,
            CalendarSampleAccessibilityID.selectionPicker,
            CalendarSampleAccessibilityID.scrollModePicker,
            CalendarSampleAccessibilityID.dayViewPicker,
            CalendarSampleAccessibilityID.horizontalHeightPicker,
        ] + CalendarScrollMode.allCases.map(\.accessibilityIdentifier)
        + SampleArchitecture.allCases.map(\.accessibilityIdentifier)
        + SampleSelectionMode.allCases.map(\.accessibilityIdentifier)
        + SampleDayViewMode.allCases.map(\.accessibilityIdentifier)
        + CalendarHorizontalHeightMode.allCases.map(\.accessibilityIdentifier)
}
