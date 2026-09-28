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
}
