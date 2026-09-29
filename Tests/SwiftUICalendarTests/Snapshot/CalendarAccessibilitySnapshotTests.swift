import Foundation
import SnapshotTesting
import SwiftUICalendarAccessibility
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar accessibility snapshots", .enabled(if: snapshotsEnabled))
struct CalendarAccessibilitySnapshotTests {
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
