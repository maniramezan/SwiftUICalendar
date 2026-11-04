import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Cell growth structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarGrowthSnapshotTests {
    @Test("Folded ideal heights match the standard cells in their panels")
    func foldedIdealHeights() {
        let regions = [
            CGRect(x: 630, y: 0, width: 40, height: 1100),
            CGRect(x: 340, y: 0, width: 40, height: 1100),
            CGRect(x: 0, y: 430, width: 1300, height: 40),
        ]
        let lines = regions.map { region in
            let ideal = CalendarIdealHeight(
                metrics: .default, showsHeader: true, growsCells: true, hostHeight: nil,
                foldRegions: [region], allowsCompanion: true)
            return "division=\(region) idealHeight=\(ideal(1300))"
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }

    @Test(
        "Grown cells preserve month structure in every scroll mode",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical],
        [Calendar.Identifier.gregorian, .persian])
    func grownMonths(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier) {
        let model = CalendarViewModel.snapshot(identifier: identifier)
        let metrics = CalendarMetrics.default.growingCells(
            toFitHeight: mode == .vertical ? nil : 1000, controls: 104)
        assertCalendarStructure(
            model: model, configuration: .init(scrollMode: mode), width: 820,
            monthSpan: mode == .none ? 0 : 1, metrics: metrics, named: "\(identifier)-\(mode)")
    }

    @Test(
        "Tall custom rows retain their readable minimum in every mode",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical])
    func tallCustomRows(mode: CalendarConfiguration.ScrollMode) {
        let model = CalendarViewModel.snapshot()
        assertCalendarStructure(
            model: model, configuration: .init(scrollMode: mode), width: 390,
            minimumCellSize: CGSize(width: 44, height: 100), named: "\(mode)")
    }

    @Test(
        "Fixed-month navigation retains the selected day after returning",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func fixedMonthNavigation(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier)
        let selected = try #require(model.engine.date(day: 12, in: model.visibleMonth))
        model.select(selected)
        try model.updateMonthToNextMonth()
        assertCalendarStructure(model: model, named: "\(identifier)-next")
        try model.updateMonthToPreviousMonth()
        assertCalendarStructure(model: model, named: "\(identifier)-returned")
    }
}
