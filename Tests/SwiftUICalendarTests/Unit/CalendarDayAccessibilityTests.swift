import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar day accessibility")
struct CalendarDayAccessibilityTests {
    @Test(
        "Spoken dates include weekday and range role without duplicating selected state",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func rangeDescriptions(identifier: Calendar.Identifier) throws {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = Date(timeIntervalSince1970: 0)
        for role in [CalendarRangePosition.start, .end, .interior, .startAndEnd] {
            let context = CalendarDayContext(
                date: date, day: 1, dayLabel: "1", isToday: false, isSelected: true,
                isInCurrentMonth: true, theme: Theme().day, typography: .default,
                onSelect: { _ in }, calendar: calendar, rangePosition: role)
            #expect(context.nativeAccessibilityLabel.contains("Thursday"))
            #expect(
                context.nativeAccessibilityLabel.contains(
                    "Calendar.Day.Range.\(role.rawValue)".localized(locale: calendar.locale!)))
            #expect(!context.nativeAccessibilityLabel.contains("Selected"))
        }
    }

    @Test("Range roles normalize reversed boundaries and exclude unselected days")
    func rangeMatcher() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let start = Date(timeIntervalSince1970: 0)
        let middle = start.addingTimeInterval(86400)
        let end = middle.addingTimeInterval(86400)
        let matcher = CalendarSelection.range(end, start).rangePositionMatcher(in: calendar)
        #expect(matcher(start) == .start)
        #expect(matcher(middle) == .interior)
        #expect(matcher(end) == .end)
        #expect(matcher(end.addingTimeInterval(86400)) == nil)
        #expect(
            CalendarSelection.range(start, nil).rangePositionMatcher(in: calendar)(start) == .start)
        #expect(
            CalendarSelection.range(start, start).rangePositionMatcher(in: calendar)(start)
                == .startAndEnd)
        #expect(CalendarSelection.range(nil, end).rangePositionMatcher(in: calendar)(end) == nil)
        #expect(CalendarSelection.single(start).rangePositionMatcher(in: calendar)(start) == nil)
        #expect(
            CalendarSelection.multiple([start]).rangePositionMatcher(in: calendar)(start) == nil)
    }

    @Test("Secondary calendar descriptions identify the calendar and full date")
    func secondaryDescriptions() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        let date = Date(timeIntervalSince1970: 0)
        let description = Theme.Day.SecondaryLabelMode.persian.accessibilityLabel(
            for: date, primaryCalendar: calendar)
        #expect(description?.contains("Persian Calendar") == true)
        #expect(description?.contains("1348") == true)
        #expect(
            Theme.Day.SecondaryLabelMode.none.accessibilityLabel(
                for: date, primaryCalendar: calendar) == nil)
        #expect(
            Theme.Day.SecondaryLabelMode.custom { _ in "Event" }.accessibilityLabel(
                for: date, primaryCalendar: calendar) == nil)
    }

    @Test("Spoken dates use the supplied calendar even with an English locale")
    func spokenCalendar() throws {
        let date = try #require(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2025, month: 6, day: 15)))
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
        #expect(context.nativeAccessibilityLabel.contains("Selected") == false)
        #expect(context.nativeAccessibilityLabel.contains("Today"))
        #expect(context.nativeAccessibilityLabel.contains("Secondary 15"))
    }

    @Test("An identical secondary calendar does not repeat the primary spoken date")
    func identicalSecondaryCalendar() {
        var calendar = Calendar(identifier: .persian)
        calendar.locale = Locale(identifier: "en_US")
        let date = Date(timeIntervalSince1970: 0)
        let secondary = Theme.Day.SecondaryLabelMode.persian.accessibilityLabel(
            for: date, primaryCalendar: calendar)
        #expect(secondary == "")
        let context = CalendarDayContext(
            date: date, day: 11, dayLabel: "11", isToday: false, isSelected: false,
            isInCurrentMonth: true, theme: Theme().day, typography: .default,
            onSelect: { _ in }, secondaryLabel: "11", calendar: calendar,
            secondaryAccessibilityLabel: secondary)
        #expect(context.secondaryLabel == "11")
        #expect(!context.nativeAccessibilityLabel.contains("Secondary"))
        #expect(!context.nativeAccessibilityLabel.contains("Persian Calendar"))
        #expect(!context.nativeAccessibilityLabel.hasSuffix(", "))
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
        #expect(context.nativeAccessibilityLabel == context.accessibilityLabel)
    }
}
