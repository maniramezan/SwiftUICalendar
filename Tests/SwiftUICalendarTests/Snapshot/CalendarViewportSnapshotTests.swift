import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar viewport snapshots", .enabled(if: snapshotsEnabled))
struct CalendarViewportSnapshotTests {
    @Test("Narrow and wide layouts preserve touch targets")
    func viewport() {
        let metrics = CalendarMetrics.default
        let lines = [240.0, 320.0, 600.0, 1024.0].map { width in
            let viewport = CalendarViewportLayout(
                width: width, minimumWidth: metrics.minCalendarWidth)
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
        let metrics = CalendarMetrics.default
        let lines = [LayoutDirection.leftToRight, .rightToLeft].map { direction in
            let span = CalendarFoldSpan.resolve(
                containerWidth: 700,
                blocked: CalendarFoldSpan.leadingOrigin(
                    [300...400], containerWidth: 700, layoutDirection: direction))
            let width = 700 - span.total
            let viewport = CalendarViewportLayout(
                width: width, minimumWidth: metrics.minCalendarWidth,
                margins: 2 * metrics.calendarMargin)
            return
                "direction=\(direction) viewport=\(width) leading=\(span.leading) trailing=\(span.trailing) content=\(viewport.contentWidth) overflow=\(viewport.overflows)"
        }
        withSnapshotTesting(record: globalRecordMode) {
            assertSnapshot(of: lines.joined(separator: "\n"), as: .lines)
        }
    }

}
