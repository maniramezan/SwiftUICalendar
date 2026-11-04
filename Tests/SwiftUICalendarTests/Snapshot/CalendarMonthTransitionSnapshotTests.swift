import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Month transition structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarMonthTransitionSnapshotTests {
    @Test(
        "Outgoing and incoming grids retain their own month during a crossfade",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func retainedMonthIdentity(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier)
        let outgoing = model.visibleMonth
        let next = try #require(model.monthIdentifier(offset: 1))
        let selected = try #require(model.engine.date(day: 1, in: next))
        model.select(selected, navigating: false)
        try model.navigate(to: selected)
        assertCalendarStructure(
            model: model, months: [outgoing], named: "\(identifier)-outgoing")
        assertCalendarStructure(model: model, named: "\(identifier)-incoming")
    }
}
