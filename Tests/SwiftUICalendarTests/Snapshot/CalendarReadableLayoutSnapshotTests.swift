import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Readable layout snapshots")
struct CalendarReadableLayoutSnapshotTests {
    @Test(arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal])
    func largerContentOverflowsWithoutShrinking(mode: CalendarConfiguration.ScrollMode) {
        assertCalendarStructure(
            model: .snapshot(identifier: .persian, selection: .single(nil)),
            configuration: .init(scrollMode: mode), width: 343,
            minimumCellSize: CGSize(width: 80, height: 120), named: "readable-\(mode)")
    }

    @Test func minimumGapFitsInsetHost() {
        assertCalendarStructure(
            model: .snapshot(selection: .single(nil)), width: 332, named: "minimum-gap")
    }
}
