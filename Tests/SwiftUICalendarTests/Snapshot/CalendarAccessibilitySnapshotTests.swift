import Foundation
import SnapshotTesting
import SwiftUI
import SwiftUICalendarAccessibility
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar accessibility snapshots", .enabled(if: snapshotsEnabled))
struct CalendarAccessibilitySnapshotTests {
    @Test(
        "Spoken range and secondary-calendar context",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func dayDescriptions(identifier: Calendar.Identifier) throws {
        var calendar = Calendar(identifier: identifier)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let date = Date(timeIntervalSince1970: 0)
        let descriptions = [CalendarRangePosition.start, .interior, .end, .startAndEnd].map {
            role in
            CalendarDayContext(
                date: date, day: 1, dayLabel: "1", isToday: false, isSelected: true,
                isInCurrentMonth: true, theme: Theme().day, typography: .default,
                onSelect: { _ in }, calendar: calendar, rangePosition: role,
                secondaryAccessibilityLabel: Theme.Day.SecondaryLabelMode.persian
                    .accessibilityLabel(
                        for: date, primaryCalendar: calendar)
            ).nativeAccessibilityLabel
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(
                of: descriptions.joined(separator: "\n"), as: .lines,
                named: "day-descriptions-\(identifier)")
        }
    }

    @Test("Header descriptions distinguish controls without repeating system gestures")
    func headerControlDescriptions() {
        let item = MonthItem(id: 6, title: "June")
        let header = CalendarNavigationHeaderView(
            items: [item], selectedItem: .constant(item), onPrevious: {}, onNext: {})
        let descriptions = [
            header.monthAccessibilityLabel,
            header.monthAccessibilityHint,
            "Calendar.Navigation.Year.ChangeHint".localized(locale: Locale(identifier: "en_US")),
            "Calendar.Navigation.PreviousYears".localized(locale: Locale(identifier: "en_US")),
            "Calendar.Navigation.NextYears".localized(locale: Locale(identifier: "en_US")),
            "verticalMonthHeader: heading",
            "yearPageTitle: heading",
            "yearOptionSelection: selectedTrait",
        ]
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(
                of: descriptions.joined(separator: "\n"), as: .lines, named: "header-descriptions")
        }
    }

    @Test(
        "Shared identifiers follow the rendered calendar",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func identifiers(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
        let month = try #require(model.monthSnapshot(for: model.visibleMonth))
        let header = CalendarAccessibilityID.verticalMonthHeader(
            year: month.id.year, month: month.id.month)
        let days = month.days.filter(\.isInDisplayedMonth).map {
            CalendarAccessibilityID.day(year: $0.year, month: $0.month, day: $0.day)
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(
                of: (Self.controlIdentifiers + [header] + days).joined(separator: "\n"), as: .lines,
                named: "identifiers-\(identifier)")
        }
        for mode in CalendarScrollMode.allCases {
            assertCalendarStructure(
                model: model, configuration: CalendarConfiguration(scrollMode: mode),
                named: "\(identifier)-\(mode)")
        }
    }

    /// The controls the header offers, in the order they appear on screen.
    private static let controlIdentifiers = [
        CalendarAccessibilityID.previousMonthButton,
        CalendarAccessibilityID.monthButton,
        CalendarAccessibilityID.nextMonthButton,
        CalendarAccessibilityID.previousYearButton,
        CalendarAccessibilityID.yearButton,
        CalendarAccessibilityID.nextYearButton,
        CalendarAccessibilityID.yearPagePreviousButton,
        CalendarAccessibilityID.yearPageNextButton,
        CalendarAccessibilityID.yearPickerDoneButton,
        CalendarAccessibilityID.todayButton,
    ]
}
