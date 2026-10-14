import Foundation
import Observation
import SwiftUI
import Synchronization
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar Scroll Preview Tests")
struct CalendarScrollPreviewTests {
    private func model(
        _ identifier: Calendar.Identifier = .gregorian, year: Int, month: Int
    ) throws -> CalendarViewModel {
        let viewModel = CalendarViewModel.test(identifier: identifier)
        let date = try #require(
            Calendar(identifier: identifier).date(
                from: DateComponents(year: year, month: month, day: 1)))
        try viewModel.navigate(to: date)
        return viewModel
    }

    @Test("a previewed month moves the header without navigating the model")
    func previewMovesHeaderOnly() throws {
        let viewModel = try model(year: 2025, month: 6)
        let visible = viewModel.visibleMonth
        let state = viewModel.state
        let august = try #require(viewModel.monthIdentifier(offset: 2))

        viewModel.previewScrolledMonth(august)

        #expect(viewModel.headerMonth == august)
        #expect(viewModel.headerYear == 2025)
        #expect(viewModel.visibleMonth == visible)
        #expect(viewModel.state == state)
    }

    @Test("previewing the visible month, or nil, makes the header follow the model again")
    func visibleOrNilClearsPreview() throws {
        let viewModel = try model(year: 2025, month: 6)
        let july = try #require(viewModel.monthIdentifier(offset: 1))

        viewModel.previewScrolledMonth(july)
        viewModel.previewScrolledMonth(viewModel.visibleMonth)
        #expect(viewModel.scrollPreviewMonth == nil)
        #expect(viewModel.headerMonth == viewModel.visibleMonth)

        viewModel.previewScrolledMonth(july)
        viewModel.previewScrolledMonth(nil)
        #expect(viewModel.scrollPreviewMonth == nil)
        #expect(viewModel.scrollPreviewYear == nil)
    }

    @Test("the year preview is set only when a scroll crosses into another year")
    func yearPreviewOnlyAcrossYears() throws {
        let viewModel = try model(year: 2025, month: 11)

        let nextMonth = try #require(viewModel.monthIdentifier(offset: 1))
        viewModel.previewScrolledMonth(nextMonth)
        #expect(viewModel.scrollPreviewYear == nil)
        #expect(viewModel.headerYear == 2025)

        let followingMonth = try #require(viewModel.monthIdentifier(offset: 2))
        viewModel.previewScrolledMonth(followingMonth)
        #expect(viewModel.scrollPreviewYear == 2026)
        #expect(viewModel.headerYear == 2026)
    }

    @Test("a month in another era is not previewed")
    func otherEraIsNotPreviewed() throws {
        let viewModel = try model(year: 2025, month: 6)
        let visible = viewModel.visibleMonth
        let otherEra = MonthIdentifier(
            month: visible.month, year: visible.year,
            calendarIdentifier: visible.calendarIdentifier, era: visible.era + 1)

        viewModel.previewScrolledMonth(otherEra)

        #expect(viewModel.scrollPreviewMonth == nil)
        #expect(viewModel.headerMonth == visible)
    }

    /// Whether `mutate` notifies an observer of whatever `read` accessed.
    private func notifies(_ read: () -> Void, when mutate: () -> Void) -> Bool {
        let changed = Mutex(false)
        withObservationTracking(read) { changed.withLock { $0 = true } }
        mutate()
        return changed.withLock { $0 }
    }

    @Test("previewing within a year does not invalidate grids or the year picker")
    func previewInvalidatesOnlyHeaderMonth() throws {
        let july = try #require(try model(year: 2025, month: 6).monthIdentifier(offset: 1))
        func notifiesOnPreview(_ read: (CalendarViewModel) -> Void) throws -> Bool {
            let viewModel = try model(year: 2025, month: 6)
            return notifies {
                read(viewModel)
            } when: {
                viewModel.previewScrolledMonth(july)
            }
        }

        #expect(try notifiesOnPreview { _ = $0.scrollPreviewMonth })
        #expect(try !notifiesOnPreview { _ = $0.scrollPreviewYear })
        // Every realized grid reads the model through `state`.
        #expect(try !notifiesOnPreview { _ = $0.selection })
    }

    @Test("repeating the same preview does not notify the header again")
    func repeatedPreviewIsSilent() throws {
        let viewModel = try model(year: 2025, month: 6)
        let july = try #require(viewModel.monthIdentifier(offset: 1))
        viewModel.previewScrolledMonth(july)

        #expect(
            !notifies {
                _ = viewModel.scrollPreviewMonth
            } when: {
                viewModel.previewScrolledMonth(july)
            })
    }

    @Test("header month items follow a previewed Hebrew year with a different month count")
    func headerMonthItemsFollowPreviewYear() throws {
        // 5786 is a common Hebrew year (12 months); 5787 is a leap year (13, adding Adar I).
        let viewModel = try model(.hebrew, year: 5786, month: 1)
        let commonYearCount = CalendarHeaderMonthView.monthItems(for: viewModel).count
        let nextYear = try #require(viewModel.monthIdentifier(offset: commonYearCount))
        #expect(nextYear.year == 5787)

        viewModel.previewScrolledMonth(nextYear)
        let items = CalendarHeaderMonthView.monthItems(for: viewModel)

        #expect(commonYearCount == 12)
        #expect(items.count == viewModel.months(in: 5787).count)
        #expect(items.count == 13)
        #expect(viewModel.headerMonth == nextYear)
    }

    @Test("a controlled model keeps previewing a settled month until its state catches up")
    func controlledModelKeepsPreviewUntilSync() throws {
        let owned = try model(year: 2025, month: 6)
        var actions: [CalendarAction] = []
        let controlled = CalendarViewModel(state: owned.state) { actions.append($0) }
        let july = try #require(controlled.monthIdentifier(offset: 1))
        let julyDate = try #require(controlled.engine.navigationDate(in: july, preferredDay: 1))

        // Mirrors `settleScrollPosition`: navigate, then re-apply the preview.
        try controlled.navigate(to: julyDate)
        controlled.previewScrolledMonth(july)
        #expect(actions.count == 1)
        #expect(controlled.headerMonth == july)

        var caughtUp = owned.state
        try caughtUp.apply(.navigate(julyDate))
        controlled.sync(state: caughtUp) { actions.append($0) }
        controlled.previewScrolledMonth(nil)
        #expect(controlled.visibleMonth == july)
        #expect(controlled.headerMonth == july)
        #expect(controlled.scrollPreviewMonth == nil)
    }

    @Test("only gesture and momentum phases count as a user scroll")
    func userScrollPhases() {
        let coordinator = ScrollSettleCoordinator()
        coordinator.recordPhase(.animating)
        #expect(!coordinator.isUserScrolling)
        for phase in [ScrollPhase.tracking, .interacting, .decelerating] {
            coordinator.recordPhase(phase)
            #expect(coordinator.isUserScrolling)
        }
        coordinator.recordPhase(.idle)
        #expect(!coordinator.isUserScrolling)
        coordinator.recordPhase(.tracking)
        coordinator.cancel()
        #expect(!coordinator.isUserScrolling)
    }
}
