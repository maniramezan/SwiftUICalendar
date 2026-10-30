import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar viewport snapshots", .enabled(if: snapshotsEnabled))
struct CalendarViewportSnapshotTests {
    @Test("Today column offsets preserve readable cells and edge margins")
    func todayColumnOffsets() {
        let lines = [240.0, 320.0, 600.0].flatMap { width in
            let layout = CalendarViewportLayout(
                width: width, cellWidth: 100, margins: 32,
                preferredSpacing: 8, minimumSpacing: 4)
            return (0..<7).map { column in
                let offset = layout.horizontalOffsetToReveal(column: column, viewportWidth: width)
                return "viewport=\(width) column=\(column) offset=\(offset)"
            }
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }

    @Test("Narrow and wide layouts preserve touch targets")
    func viewport() {
        let metrics = CalendarMetrics.default
        let lines = [240.0, 320.0, 600.0, 1024.0].map { width in
            let viewport = CalendarViewportLayout(
                width: width, cellWidth: metrics.minCellSize, margins: 0,
                preferredSpacing: metrics.itemSpacing, minimumSpacing: metrics.itemSpacing)
            let grid = CalendarGridLayout(containerWidth: viewport.contentWidth, metrics: metrics)
            return
                "viewport=\(width) content=\(viewport.contentWidth) overflow=\(viewport.overflows) cell=\(grid.cellSize)"
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }
    @Test("Fold bands retain overflow geometry in both reading directions")
    func foldedViewport() {
        let lines = [LayoutDirection.leftToRight, .rightToLeft].map { direction in
            describeFold(
                size: CGSize(width: 700, height: 800),
                blocked: [CGRect(x: 300, y: 0, width: 100, height: 800)], direction: direction)
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }

    @Test("Live geometry resolves book, tabletop, and flat transitions")
    func liveGeometry() {
        let folds: [[CGRect]] = [
            [], [CGRect(x: 430, y: 0, width: 40, height: 800)],
            [CGRect(x: 0, y: 380, width: 900, height: 40)],
            [CGRect(x: 520, y: 0, width: 60, height: 800)], [],
        ]
        let lines = [LayoutDirection.leftToRight, .rightToLeft].flatMap { direction in
            folds.map {
                describeFold(
                    size: CGSize(width: 900, height: 800), blocked: $0, direction: direction)
            }
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }

    @Test(
        "Two folded months share range selection in every scroll mode",
        arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal],
        [Calendar.Identifier.gregorian, .persian])
    func consecutiveMonths(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .range(nil, nil))
        let next = try #require(model.monthIdentifier(offset: 1))
        let currentDays = try #require(model.monthSnapshot(for: model.visibleMonth))
        let nextDays = try #require(model.monthSnapshot(for: next))
        let start = try #require(currentDays.days.last { $0.isInDisplayedMonth }?.date)
        let end = try #require(nextDays.days.first { $0.isInDisplayedMonth }?.date)
        model.select(start)
        model.select(end)
        let primaryMode: CalendarConfiguration.ScrollMode = mode == .vertical ? .none : mode
        let documents = [
            CalendarStructure.render(
                model: model, configuration: .init(scrollMode: primaryMode), theme: Theme(),
                width: 430, monthSpan: 0, months: [model.visibleMonth], hideOverflowDays: true),
            CalendarStructure.render(
                model: model, configuration: .init(scrollMode: .none), theme: Theme(),
                width: 430, monthSpan: 0, months: [next], hideOverflowDays: true),
        ]
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(
                of: "requestedScrollMode: \(mode)\n\nprimary panel\n"
                    + documents.joined(separator: "\ncompanion panel\n"), as: .lines,
                named: "\(identifier)-\(mode)")
        }
    }

    private func describeFold(
        size: CGSize, blocked: [CGRect], direction: LayoutDirection
    ) -> String {
        let fold = CalendarFoldLayout.resolve(
            size: size, blocked: blocked, minimumPaneSize: CGSize(width: 332, height: 132),
            allowsCompanion: true, layoutDirection: direction)
        let metrics = CalendarMetrics.default
        let viewport = CalendarViewportLayout(
            width: fold.primary.width, cellWidth: metrics.minCellSize,
            margins: 2 * metrics.calendarMargin,
            preferredSpacing: metrics.itemSpacing, minimumSpacing: 4)
        let secondary = fold.secondary.map { "\($0)" } ?? "none"
        return
            "direction=\(direction) mode=\(fold.mode) primary=\(fold.primary) secondary=\(secondary) content=\(viewport.contentWidth) overflow=\(viewport.overflows)"
    }
}
