import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Month transition structural snapshots", .enabled(if: snapshotsEnabled))
struct CalendarMonthTransitionSnapshotTests {
    @Test(
        "The fixed grid follows the externally committed month after an overflow tap",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func controlledOverflow(identifier: Calendar.Identifier) throws {
        let initial = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            .state
        var requestedAction: CalendarAction?
        let recordAction: (CalendarAction) -> Void = { requestedAction = $0 }
        let model = CalendarViewModel(state: initial, onAction: recordAction)
        let view = CalendarFixedMonthView(
            viewModel: model, layoutWidth: nil, keyboard: CalendarKeyboardCursor())
        let next = try #require(model.monthIdentifier(offset: 1))
        let date = try #require(model.engine.start(of: next))

        view.selectOverflowDate(date)
        assertCalendarStructure(model: model, named: "\(identifier)-uncommitted-overflow")

        var committed = initial
        try committed.apply(try #require(requestedAction))
        model.sync(state: committed, onAction: recordAction)
        assertCalendarStructure(model: model, named: "\(identifier)-committed-overflow")
    }

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
