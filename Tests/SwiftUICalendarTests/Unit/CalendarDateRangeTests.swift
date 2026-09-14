import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar date range")
struct CalendarDateRangeTests {

    private func utcCalendar(_ identifier: Calendar.Identifier = .gregorian) throws -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int, hour: Int = 0, in calendar: Calendar
    ) throws -> Date {
        try #require(
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
    }

    // MARK: - Helpers

    @Test("onOrAfter and onOrBefore bound one side and leave the other open")
    func openEndedHelpers() throws {
        let calendar = try utcCalendar()
        let pivot = try date(2025, 6, 15, hour: 14, in: calendar)

        #expect(ClosedRange<Date>.onOrAfter(pivot) == pivot...Date.distantFuture)
        #expect(ClosedRange<Date>.onOrBefore(pivot) == Date.distantPast...pivot)
    }

    @Test("years(_:in:) spans the first through the last instant of the years")
    func yearsHelperGregorian() throws {
        let calendar = try utcCalendar()
        let range = try ClosedRange<Date>.years(2020...2021, in: calendar)

        #expect(range.lowerBound == (try date(2020, 1, 1, in: calendar)))
        #expect(range.upperBound < (try date(2022, 1, 1, in: calendar)))
        #expect(range.upperBound > (try date(2021, 12, 31, hour: 23, in: calendar)))
    }

    @Test("years(_:in:) follows the supplied calendar's year boundaries")
    func yearsHelperPersian() throws {
        let persian = try utcCalendar(.persian)
        let range = try ClosedRange<Date>.years(1404...1404, in: persian)

        #expect(persian.component(.year, from: range.lowerBound) == 1404)
        #expect(persian.component(.month, from: range.lowerBound) == 1)
        #expect(persian.component(.day, from: range.lowerBound) == 1)
        #expect(persian.component(.year, from: range.upperBound) == 1404)
    }

    // MARK: - State

    @Test("dateRange is intersected with the supported interval")
    func dateRangeClampsToSupportedInterval() throws {
        let calendar = try utcCalendar()
        let start = try date(2025, 1, 1, in: calendar)
        let state = try CalendarState(
            calendar: calendar, currentDate: try date(2025, 6, 1, in: calendar),
            dateRange: .onOrAfter(start))

        #expect(state.dateRange.lowerBound == start)
        #expect(state.dateRange.upperBound < (try date(2101, 1, 1, in: calendar)))
    }

    @Test("explicit initialization rejects a current date or range outside the allowed dates")
    func explicitInitializationValidatesRange() throws {
        let calendar = try utcCalendar()
        let early = try date(2024, 6, 1, in: calendar)
        let current = try date(2025, 6, 1, in: calendar)
        let futureOnly = ClosedRange<Date>.onOrAfter(try date(2025, 1, 1, in: calendar))
        let unsupported =
            (try date(1700, 1, 1, in: calendar))...(try date(1800, 1, 1, in: calendar))

        #expect(throws: (any Error).self) {
            try CalendarState(calendar: calendar, currentDate: early, dateRange: futureOnly)
        }
        #expect(throws: (any Error).self) {
            try CalendarState(calendar: calendar, currentDate: current, dateRange: unsupported)
        }
    }

    @Test("month navigation stops at the range and clamps into partially allowed months")
    func navigationStopsAtBounds() throws {
        let calendar = try utcCalendar()
        let lower = try date(2025, 2, 15, in: calendar)
        var state = try CalendarState(
            calendar: calendar, currentDate: try date(2025, 3, 10, in: calendar),
            dateRange: lower...(try date(2025, 4, 10, in: calendar)))

        #expect(throws: (any Error).self) { try state.apply(.offsetMonths(-2)) }
        #expect(throws: (any Error).self) { try state.apply(.offsetMonths(2)) }
        #expect(calendar.component(.month, from: state.currentDate) == 3)

        try state.apply(.offsetMonths(-1))

        #expect(calendar.component(.month, from: state.currentDate) == 2)
        #expect(state.currentDate >= lower)
    }

    @Test("selection rejects days outside the range but allows a range that starts mid-day")
    func selectionObeysRangePerDay() throws {
        let calendar = try utcCalendar()
        let start = try date(2025, 6, 15, hour: 14, in: calendar)
        var state = try CalendarState(
            calendar: calendar, currentDate: start, dateRange: .onOrAfter(start))
        let dayBefore = try date(2025, 6, 14, in: calendar)
        let startDay = try date(2025, 6, 15, in: calendar)

        #expect(throws: (any Error).self) {
            try state.apply(.select(dayBefore, navigating: false))
        }

        try state.apply(.select(startDay, navigating: false))

        #expect(state.selection == .single(startDay))
    }

    // MARK: - Model

    @Test("month snapshots disable exactly the days outside the range")
    func snapshotMarksDisabledDays() throws {
        let calendar = try utcCalendar()
        let state = try CalendarState(
            calendar: calendar, currentDate: try date(2025, 6, 20, in: calendar),
            dateRange: .onOrAfter(try date(2025, 6, 15, hour: 9, in: calendar)))
        let model = CalendarViewModel(state: state)
        model.renderCache = CalendarRenderCache()

        let snapshot = try #require(model.monthSnapshot(for: model.visibleMonth))
        let june = snapshot.days.filter(\.isInDisplayedMonth)

        #expect(june.filter { !$0.isEnabled }.map(\.day) == Array(1...14))
        #expect(june.first(where: \.isEnabled)?.day == 15)
    }

    @Test("Today is unavailable when today falls outside the range")
    func todayAvailability() throws {
        let calendar = try utcCalendar()
        let past = try date(2020, 1, 1, in: calendar)
        let pastOnly = CalendarViewModel(
            state: try CalendarState(
                calendar: calendar, currentDate: past, dateRange: .onOrBefore(past)))
        let unrestricted = CalendarViewModel(
            state: try CalendarState(calendar: calendar, currentDate: past))

        #expect(pastOnly.canGoToToday == false)
        #expect(unrestricted.canGoToToday)
    }

    @Test("the convenience initializer clamps today into the range instead of throwing")
    func convenienceInitializerClampsToday() {
        let past = Date(timeIntervalSinceNow: -400 * 86_400)
        let model = CalendarViewModel(calendarIdentifier: .gregorian, dateRange: .onOrBefore(past))

        #expect(model.currentDate <= past)
        #expect(model.dateRange.upperBound == past)
    }

    @Test("month-offset cache entries are not shared between different ranges")
    func offsetCacheRespectsRange() throws {
        let calendar = try utcCalendar()
        let current = try date(2025, 6, 1, in: calendar)
        let cache = CalendarRenderCache()
        let narrow = CalendarViewModel(
            state: try CalendarState(
                calendar: calendar, currentDate: current,
                dateRange: current...(try date(2025, 6, 30, in: calendar))))
        let unrestricted = CalendarViewModel(
            state: try CalendarState(calendar: calendar, currentDate: current))
        narrow.renderCache = cache
        unrestricted.renderCache = cache

        #expect(narrow.monthIdentifier(offset: 1) == nil)
        #expect(unrestricted.monthIdentifier(offset: 1) != nil)
        #expect(narrow.monthIdentifier(offset: 1) == nil)
    }

    // MARK: - Vertical window

    @Test(
        "single-instant ranges retain their date through month and year navigation",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func singleInstantNavigation(identifier: Calendar.Identifier) throws {
        let calendar = try utcCalendar(identifier)
        let instant = Date(timeIntervalSinceReferenceDate: 771_724_800)
        var state = try CalendarState(
            calendar: calendar, currentDate: instant, dateRange: instant...instant)

        #expect(state.engine.navigationDate(in: state.visibleMonth, preferredDay: 31) == instant)
        try state.apply(.navigateMonth(state.visibleMonth))
        try state.apply(.navigateYear(calendar.component(.year, from: instant)))
        try state.apply(.offsetYears(0))
        #expect(state.currentDate == instant)
        #expect(
            state.engine.yearBounds(containing: instant) == calendar.component(
                .year, from: instant)...calendar.component(.year, from: instant))
    }

    @Test("navigation includes a closed upper bound at the start of a year")
    func midnightUpperBound() throws {
        let calendar = try utcCalendar()
        let upper = try date(2026, 1, 1, in: calendar)
        var state = try CalendarState(
            calendar: calendar, currentDate: try date(2025, 12, 31, in: calendar),
            dateRange: (try date(2025, 1, 1, in: calendar))...upper)
        try state.apply(.offsetMonths(1))
        #expect(state.currentDate == upper)
        #expect(state.maxYear == 2026)
    }

    @Test(
        "Today clamps within an available boundary day and rejects other days",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func todayBoundaryDay(identifier: Calendar.Identifier) throws {
        let calendar = try utcCalendar(identifier)
        let instant = Date(timeIntervalSinceReferenceDate: 771_768_000)
        for selection in [CalendarSelection.single(nil), .range(nil, nil), .multiple([])] {
            var state = try CalendarState(
                calendar: calendar, currentDate: instant, selection: selection,
                dateRange: instant...instant)
            for now in [instant.addingTimeInterval(-60), instant.addingTimeInterval(60)] {
                try state.apply(.today, now: now)
                #expect(state.currentDate == instant)
                if case .single = selection {
                    #expect(state.selection == .single(calendar.startOfDay(for: instant)))
                } else {
                    #expect(state.selection == selection)
                }
            }
            let before = state
            #expect(throws: (any Error).self) {
                try state.apply(.today, now: instant.addingTimeInterval(86_400))
            }
            #expect(state == before)
        }
    }

    @Test("the vertical window re-centers only far from its anchor with months beyond the edge")
    func verticalWindowRecenterPolicy() {
        #expect(VerticalMonthWindow.offsets.count == VerticalMonthWindow.radius * 2 + 1)
        #expect(
            !VerticalMonthWindow.shouldRecenter(offsetFromAnchor: 59, hasMonthsBeyondEdge: true))
        #expect(
            VerticalMonthWindow.shouldRecenter(offsetFromAnchor: -60, hasMonthsBeyondEdge: true))
        #expect(
            !VerticalMonthWindow.shouldRecenter(offsetFromAnchor: 200, hasMonthsBeyondEdge: false))
    }
}
