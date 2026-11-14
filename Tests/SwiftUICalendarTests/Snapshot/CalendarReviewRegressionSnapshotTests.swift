import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar review regression snapshots", .enabled(if: snapshotsEnabled))
struct CalendarReviewRegressionSnapshotTests {
    @Test(
        "Today rolls over in each calendar and scroll mode",
        arguments: CalendarConfiguration.ScrollMode.allCases,
        [Calendar.Identifier.gregorian, .persian])
    func rollover(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .range(nil, nil))
        let calendar = model.engine.calendar
        let start = calendar.startOfDay(for: model.currentDate)
        let next = try #require(calendar.date(byAdding: .day, value: 1, to: start))
        model.selection = .range(start, next)
        model.refreshToday(now: start)
        let before = model.monthSnapshot(for: model.visibleMonth)?.days.first(where: \.isToday)?.day
        model.refreshToday(now: next)
        let after = model.monthSnapshot(for: model.visibleMonth)?.days.first(where: \.isToday)?.day
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(
                of: "before: \(String(describing: before))\nafter: \(String(describing: after))",
                as: .lines, named: "today-marker-\(identifier)-\(mode)")
        }
        assertCalendarStructure(
            model: model, configuration: .init(scrollMode: mode),
            named: "rollover-\(identifier)-\(mode)")
    }

    @Test(
        "Headers and accessibility strings use the calendar language",
        arguments: ["en", "de", "fa", "ar", "he"])
    func localization(language: String) {
        let locale = Locale(identifier: language)
        let keys = [
            "Calendar.Today", "Calendar.Done", "Calendar.Navigation.Month.ChangeHint",
            "Calendar.Navigation.Year.ChangeHint", "Calendar.Day.Today", "Calendar.Day.Selected",
            "Calendar.Day.Range.start", "Calendar.Day.Range.end", "Calendar.Day.Range.interior",
        ]
        let lines = keys.map { "\($0): \($0.localized(locale: locale))" }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines, named: language)
        }
    }

    @Test("Shallow tabletop folds keep one month in both writing directions")
    func shallowTabletop() {
        let metrics = CalendarMetrics.default
        let lines = [LayoutDirection.leftToRight, .rightToLeft].map { direction in
            let fold = CalendarFoldLayout.resolve(
                size: CGSize(width: 900, height: 800),
                blocked: [CGRect(x: 0, y: 180, width: 900, height: 40)],
                minimumPaneSize: CGSize(width: 332, height: metrics.minimumCompanionPanelHeight),
                allowsCompanion: true, layoutDirection: direction)
            return
                "\(direction): \(fold.mode) primary=\(fold.primary) secondary=\(String(describing: fold.secondary))"
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }
}
