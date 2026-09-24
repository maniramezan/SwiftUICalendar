import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar keyboard snapshots", .enabled(if: snapshotsEnabled))
struct CalendarKeyboardSnapshotTests {
    @Test("Focus is distinct from selection", arguments: [Calendar.Identifier.gregorian, .persian])
    func focus(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier)
        let cursor = CalendarKeyboardCursor()
        let tapped = try #require(
            model.engine.calendar.date(byAdding: .day, value: 1, to: model.currentDate))
        #expect(cursor.focus(on: tapped, model: model, shortcuts: .all))
        try model.navigate(to: tapped)
        let date = try #require(cursor.date)
        let before =
            "focused=\(cursor.isFocused(date)) selected=\(model.isSelected(date: date))"
        cursor.select(model: model)
        let after =
            "focused=\(cursor.isFocused(date)) selected=\(model.isSelected(date: date))"
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: before + "\n" + after, as: .lines, named: "focus-\(identifier)")
        }
        assertCalendarStructure(model: model, named: "keyboard-selection-\(identifier)")
    }
}
