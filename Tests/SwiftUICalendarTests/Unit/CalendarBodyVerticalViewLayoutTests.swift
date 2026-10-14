import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyVerticalView Layout Tests", .serialized)
struct CalendarBodyVerticalViewLayoutTests {
    @Test("user scroll phases allow settlement and programmatic navigation clears it")
    func distinguishesUserScrollFromProgrammaticReveal() {
        let coordinator = ScrollSettleCoordinator()
        coordinator.recordPhase(.animating)
        coordinator.recordPhase(.idle)
        #expect(coordinator.hasUserInteraction == false)
        for phase in [ScrollPhase.tracking, .interacting, .decelerating] {
            coordinator.recordPhase(phase)
            coordinator.recordPhase(.idle)
            #expect(coordinator.hasUserInteraction)
            coordinator.cancel()
            #expect(coordinator.hasUserInteraction == false)
        }
    }

    @Test("settlement notifications are consumed once even when already aligned")
    func consumesAlignedSettlement() {
        let coordinator = ScrollSettleCoordinator()
        let month = MonthIdentifier(month: 6, year: 2025)
        coordinator.recordSettled(month)
        #expect(coordinator.consumeSettledMonth(month))
        #expect(!coordinator.consumeSettledMonth(month))
    }

    @Test("external navigation invalidates an outstanding settlement marker")
    func externalNavigationClearsSettlement() {
        let coordinator = ScrollSettleCoordinator()
        let settled = MonthIdentifier(month: 6, year: 2025)
        let external = MonthIdentifier(month: 9, year: 2025)
        coordinator.recordSettled(settled)
        #expect(!coordinator.consumeSettledMonth(external))
        #expect(!coordinator.consumeSettledMonth(settled))
        coordinator.recordSettled(settled)
        coordinator.cancel()
        #expect(!coordinator.consumeSettledMonth(settled))
    }

    @Test("month title width matches the grid's compact width in a wide (landscape) layout")
    func monthTitleWidthMatchesGridWidthInLandscape() {
        let metrics = CalendarMetrics.default

        // A wide, landscape-style container saturates the cell size at `maxCellSize`, which makes
        // `CalendarGridLayout` shrink the grid to its natural (compact) width and center it — the
        // scenario that left the vertical list's per-month title, previously pinned to the full row
        // width, misaligned with the narrower, centered grid beneath it.
        let landscapeWidth: CGFloat = 900
        let layout = CalendarGridLayout(
            containerWidth: landscapeWidth, metrics: metrics, sizing: .adaptive)

        #expect(layout.gridWidth < landscapeWidth)
        #expect(layout.cellSize == metrics.maxCellSize)

        // `VerticalMonthView` resolves its title width from the same `CalendarGridLayout` call as
        // `CalendarBodyView` resolves its grid width, so the two stay in lockstep at any width.
        let bodyLayout = CalendarGridLayout(
            containerWidth: landscapeWidth, metrics: metrics, sizing: .adaptive)
        #expect(layout.gridWidth == bodyLayout.gridWidth)
    }

    @Test("vertical destination preserves a distant month across a year boundary")
    func followsDistantPositionAcrossYearBoundary() throws {
        let vm = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let calendar = Calendar(identifier: .gregorian)
        let currentDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 13)))
        try vm.navigate(to: currentDate)

        let reported = try #require(vm.monthIdentifier(offset: -18))
        let date = try #require(vm.engine.navigationDate(in: reported, preferredDay: 1))
        try vm.navigate(to: date)

        #expect(vm.visibleMonth == reported)
    }

    #if os(macOS)
    @Test("Today reveals its day again after resizing without changing the date")
    func hostedTodayAfterResize() throws {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let model = CalendarViewModel(
            state: try CalendarState(
                calendar: calendar, currentDate: now, selection: .single(now),
                dateRange: .onOrBefore(now)))
        let frames = MeasuredDayFrames(calendar: calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: .vertical)),
            size: CGSize(width: 744, height: 420))
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        model.goToToday()
        #expect(waitForStableRender(hosted.hosting))
        let date = model.currentDate
        let resized = CGSize(width: 744, height: 300)
        hosted.window.setContentSize(resized)
        #expect(waitForStableRender(hosted.hosting))
        for _ in 0..<2 {
            model.goToToday()
            #expect(waitForStableRender(hosted.hosting))
            #expect(model.currentDate == date)
            let frame = try #require(frames.inMonth[calendar.startOfDay(for: now)])
            #expect(CGRect(origin: .zero, size: resized).contains(frame))
        }
    }

    @Test(
        "repeated distant navigation places the requested month inside the actual viewport",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func hostedNavigationRevealsRequestedMonth(identifier: Calendar.Identifier) throws {
        let gregorian = Calendar(identifier: .gregorian)
        let end = try #require(gregorian.date(from: DateComponents(year: 2025, month: 6, day: 12)))
        let start = try #require(gregorian.date(from: DateComponents(year: 1900, month: 1, day: 1)))
        let model = CalendarViewModel(
            state: try CalendarState(
                calendarIdentifier: identifier, currentDate: end, selection: .single(end),
                dateRange: start...end))
        let original = model.visibleMonth
        let frames = MeasuredDayFrames(calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let size = CGSize(width: 744, height: 420)
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: .vertical)),
            size: size)
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))

        for offset in [-8, 0, -1, 0, -14, 0] {
            let month = try #require(model.monthIdentifier(offset: offset, from: original))
            let day = try #require(model.engine.navigationDate(in: month, preferredDay: 12))
            try model.navigate(to: day)
            #expect(waitForStableRender(hosted.hosting))
            #expect(model.visibleMonth == month)
            let dayStart = model.engine.calendar.startOfDay(for: day)
            let frame = try #require(frames.inMonth[dayStart])
            #expect(
                CGRect(origin: .zero, size: size).contains(frame),
                "Navigation to offset \(offset) left the requested day outside the viewport: \(frame)"
            )
        }
    }

    @Test("narrow vertical viewport aligns consecutive month jumps",
          arguments: [Calendar.Identifier.gregorian, .persian], [CGFloat(44), 72])
    func hostedNarrowConsecutiveMonthJumps(identifier: Calendar.Identifier, minimumDayHeight: CGFloat) throws {
        let gregorian = Calendar(identifier: .gregorian)
        let end = try #require(gregorian.date(from: DateComponents(year: 2026, month: 10, day: 14)))
        let model = CalendarViewModel(
            state: try CalendarState(
                calendarIdentifier: identifier, currentDate: end, selection: .single(end),
                dateRange: .onOrBefore(end)))
        let original = model.visibleMonth
        let frames = MeasuredDayFrames(calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent(minimumSize: { _ in CGSize(width: 44, height: minimumDayHeight) }) {
            MeasuringDayView(context: $0, frames: frames)
        }
        let size = CGSize(width: 359, height: 494)
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: .vertical)),
            size: size)
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))

        for offset in [-1, -2, -3, 0] {
            let month = try #require(model.monthIdentifier(offset: offset, from: original))
            let day = try #require(model.engine.navigationDate(in: month, preferredDay: 1))
            try model.navigate(to: day)
            #expect(waitForStableRender(hosted.hosting))
            let frame = try #require(frames.inMonth[model.engine.calendar.startOfDay(for: day)])
            #expect(CGRect(origin: .zero, size: size).contains(frame),
                    "Requested month is outside the narrow viewport: \(month), \(frame)")
        }
    }

    @Test("hosted vertical view follows external navigation without crashing")
    func hostedVerticalViewFollowsExternalNavigation() throws {
        let viewModel = CalendarViewModel.snapshot(selection: .single(nil))
        let view = CalendarBodyVerticalView()
            .environment(viewModel)
            .environment(Theme())
            .environment(Typography.default)
            .environment(\.locale, viewModel.locale)
            .environment(\.layoutDirection, viewModel.layoutDirection)

        let hosted = hostView(view, size: CGSize(width: 390, height: 600))

        // Drive the external-navigation synchronization path while hosted.
        let gregorian = Calendar(identifier: .gregorian)
        let target = try #require(
            gregorian.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        try viewModel.navigate(to: target)
        hosted.hosting.layoutSubtreeIfNeeded()
        if let bitmap = hosted.hosting.bitmapImageRepForCachingDisplay(
            in: hosted.hosting.bounds)
        {
            hosted.hosting.cacheDisplay(in: hosted.hosting.bounds, to: bitmap)
        }
        hosted.window.contentView = nil

        #expect(viewModel.visibleMonth == MonthIdentifier(month: 3, year: 2026))
    }

    #endif
}
