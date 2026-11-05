import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Month transition structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarMonthTransitionSnapshotTests {
    @Test(
        "Shared dates retain their identity in outgoing and incoming month grids",
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

    @Test(
        "Incoming month snapshot precedes overflow selection until fade-in completes",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func overflowSelectionWaitsForFadeIn(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
        let currentMonth = model.visibleMonth
        let targetMonth = try #require(model.monthIdentifier(offset: 1))
        let targetDate = try #require(model.engine.date(day: 15, in: targetMonth))
        let fade = CalendarMonthFade(month: currentMonth)
        let token = try #require(fade.begin(to: targetMonth, selecting: targetDate))

        #expect(try fade.finishFadeOut(token, model: model))
        assertCalendarStructure(
            model: model, months: [fade.displayedMonth],
            named: "\(identifier)-incoming-before-overflow-selection")

        fade.finishFadeIn(token, model: model)
        assertCalendarStructure(
            model: model, months: [fade.displayedMonth],
            named: "\(identifier)-incoming-after-overflow-selection")
    }
}
