import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Month fade coordinator", .serialized)
struct CalendarMonthTransitionTests {
    private struct Dates {
        let currentMonth: MonthIdentifier
        let nextMonth: MonthIdentifier
        let followingMonth: MonthIdentifier
        let originalStart: Date
        let originalEnd: Date
        let firstTarget: Date
        let secondTarget: Date
    }

    private func dates(identifier: Calendar.Identifier) throws -> Dates {
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(nil))
        let currentMonth = model.visibleMonth
        let nextMonth = try #require(model.monthIdentifier(offset: 1))
        let followingMonth = try #require(model.monthIdentifier(offset: 2))
        return Dates(
            currentMonth: currentMonth,
            nextMonth: nextMonth,
            followingMonth: followingMonth,
            originalStart: try #require(model.engine.date(day: 10, in: currentMonth)),
            originalEnd: try #require(model.engine.date(day: 12, in: currentMonth)),
            firstTarget: try #require(model.engine.date(day: 15, in: nextMonth)),
            secondTarget: try #require(model.engine.date(day: 15, in: followingMonth)))
    }

    @Test(
        "Selection stays unchanged through fade-out and changes after fade-in",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func selectionCommitsAfterFadeIn(identifier: Calendar.Identifier) throws {
        let dates = try dates(identifier: identifier)
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(nil))
        let original = model.engine.calendar.startOfDay(for: dates.originalStart)
        let target = model.engine.calendar.startOfDay(for: dates.firstTarget)
        model.select(original)
        let fade = CalendarMonthFade(month: dates.currentMonth)

        let token = try #require(fade.begin(to: dates.nextMonth, selecting: dates.firstTarget))
        #expect(model.selection == .single(original))
        #expect(try fade.finishFadeOut(token, model: model))
        #expect(model.selection == .single(original))
        #expect(fade.displayedMonth == dates.nextMonth)
        #expect(fade.targetMonth == dates.nextMonth)

        fade.finishFadeIn(token, model: model)
        #expect(model.selection == .single(target))
    }

    @Test("A same-month request does not start a fade")
    func sameMonthRequestIsSkipped() throws {
        let dates = try dates(identifier: .gregorian)
        let model = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let fade = CalendarMonthFade(month: dates.currentMonth)

        #expect(fade.begin(to: dates.currentMonth) == nil)
        #expect(fade.displayedMonth == dates.currentMonth)
        #expect(model.selection == .single(nil))
    }

    @Test(
        "Header navigation preserves the current selection",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func headerNavigationPreservesSelection(identifier: Calendar.Identifier) throws {
        let dates = try dates(identifier: identifier)
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(nil))
        let original = model.engine.calendar.startOfDay(for: dates.originalStart)
        model.select(original)
        let fade = CalendarMonthFade(month: dates.currentMonth)
        let token = try #require(fade.begin(to: dates.nextMonth))

        #expect(try fade.finishFadeOut(token, model: model))
        #expect(model.selection == .single(original))
        fade.finishFadeIn(token, model: model)
        #expect(model.selection == .single(original))
    }

    @Test(
        "Range and multiple selections remain unchanged until fade-in finishes",
        arguments: [false, true])
    func compoundSelectionCommitsAfterFadeIn(isMultiple: Bool) throws {
        let dates = try dates(identifier: .gregorian)
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: dates.originalStart)
        let end = calendar.startOfDay(for: dates.originalEnd)
        let target = calendar.startOfDay(for: dates.firstTarget)
        let original: CalendarViewModel.Selection =
            isMultiple
            ? .multiple([start, end])
            : .range(start, end)
        let model = CalendarViewModel.test(identifier: .gregorian, selection: original)
        let fade = CalendarMonthFade(month: dates.currentMonth)
        let token = try #require(fade.begin(to: dates.nextMonth, selecting: target))

        #expect(model.selection == original)
        #expect(try fade.finishFadeOut(token, model: model))
        #expect(model.selection == original)
        fade.finishFadeIn(token, model: model)

        let expected: CalendarViewModel.Selection =
            isMultiple
            ? .multiple([start, end, target])
            : .range(target, nil)
        #expect(model.selection == expected)
    }

    @Test("Retargeting during fade-out keeps the token and uses the latest destination")
    func retargetDuringFadeOutUsesLatestDestination() throws {
        let dates = try dates(identifier: .gregorian)
        let model = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let fade = CalendarMonthFade(month: dates.currentMonth)
        let token = try #require(fade.begin(to: dates.nextMonth, selecting: dates.firstTarget))

        #expect(fade.begin(to: dates.followingMonth, selecting: dates.secondTarget) == nil)
        #expect(try fade.finishFadeOut(token, model: model))
        #expect(fade.displayedMonth == dates.followingMonth)
        #expect(model.selection == .single(nil))
        fade.finishFadeIn(token, model: model)
        #expect(
            model.selection == .single(model.engine.calendar.startOfDay(for: dates.secondTarget)))
    }

    @Test("A retarget during fade-in invalidates the stale completion")
    func retargetDuringFadeInIgnoresStaleCompletion() throws {
        let dates = try dates(identifier: .gregorian)
        let model = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let fade = CalendarMonthFade(month: dates.currentMonth)
        let staleToken = try #require(
            fade.begin(to: dates.nextMonth, selecting: dates.firstTarget))
        #expect(try fade.finishFadeOut(staleToken, model: model))

        let activeToken = try #require(
            fade.begin(to: dates.followingMonth, selecting: dates.secondTarget))
        fade.finishFadeIn(staleToken, model: model)
        #expect(model.selection == .single(nil))
        #expect(fade.displayedMonth == dates.nextMonth)
        #expect(try fade.finishFadeOut(activeToken, model: model))
        #expect(fade.displayedMonth == dates.followingMonth)
        #expect(model.selection == .single(nil))
        fade.finishFadeIn(activeToken, model: model)
        #expect(
            model.selection == .single(model.engine.calendar.startOfDay(for: dates.secondTarget)))
    }

    @Test("Cancellation suppresses pending overflow selection")
    func cancellationSuppressesPendingSelection() throws {
        let dates = try dates(identifier: .gregorian)
        let model = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let fade = CalendarMonthFade(month: dates.currentMonth)
        let token = try #require(fade.begin(to: dates.nextMonth, selecting: dates.firstTarget))

        fade.cancel(showing: dates.currentMonth)
        #expect(try !fade.finishFadeOut(token, model: model))
        fade.finishFadeIn(token, model: model)
        #expect(model.selection == .single(nil))
        #expect(fade.displayedMonth == dates.currentMonth)
        #expect(fade.opacity == 1)
    }
}
