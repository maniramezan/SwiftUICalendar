import Combine
import Foundation
import Observation
import Synchronization
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar day rollover")
struct CalendarDayRolloverTests {
    @MainActor
    private final class RolloverSchedule {
        var now: Date
        private(set) var deadline: Date?
        private(set) var fire: (@MainActor () -> Void)?
        private(set) var cancellations = 0

        init(now: Date) {
            self.now = now
        }

        func schedule(at deadline: Date, fire: @escaping @MainActor () -> Void) -> AnyCancellable {
            self.deadline = deadline
            self.fire = fire
            return AnyCancellable { [weak self] in self?.cancellations += 1 }
        }
    }

    @Test(
        "Midnight moves Today without navigating or changing selection",
        arguments: [Calendar.Identifier.gregorian, .persian], [false, true])
    func midnight(identifier: Calendar.Identifier, crossesMonth: Bool) throws {
        let model = CalendarViewModel.test(identifier: identifier)
        let calendar = model.engine.calendar
        let interval = try #require(model.engine.interval(of: model.visibleMonth))
        let first =
            crossesMonth
            ? calendar.startOfDay(for: interval.end.addingTimeInterval(-1))
            : interval.start
        let next = try #require(calendar.dateInterval(of: .day, for: first)?.end)
        let nextMonth = model.engine.month(containing: next)
        try model.navigate(to: first)
        model.selection = .single(first)
        let state = model.state
        model.refreshToday(now: first)
        #expect(
            model.monthSnapshot(for: model.visibleMonth)?.days.first(where: \.isToday)?.dayStart
                == first)
        let invalidated = Mutex(false)
        withObservationTracking {
            _ = model.monthSnapshot(for: model.visibleMonth)
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        model.refreshToday(now: next)
        #expect(invalidated.withLock { $0 })
        #expect(
            model.monthSnapshot(for: nextMonth)?.days.first(where: \.isToday)?.dayStart
                == next)
        let day = calendar.component(.day, from: next)
        #expect(model.isToday(day: day, month: nextMonth.month, year: nextMonth.year))
        #expect(model.isToday(day) == !crossesMonth)
        #expect(model.state == state)
    }

    @Test(
        "System notifications invalidate locally and externally owned projections",
        arguments: [
            Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange,
            .NSSystemClockDidChange,
        ])
    func notifications(name: Notification.Name) async {
        let owned = CalendarViewModel.test()
        let controlled = CalendarViewModel(
            state: owned.state,
            onAction: { _ in Issue.record("Clock refresh must not dispatch a host action") })
        let center = NotificationCenter()
        owned.observeDayChanges(in: center)
        controlled.observeDayChanges(in: center)
        let old = Date(timeIntervalSince1970: 0)
        owned.refreshToday(now: old)
        controlled.refreshToday(now: old)
        center.post(name: name, object: nil)
        for _ in 0..<100 {
            if owned.todayReference != old && controlled.todayReference != old { break }
            await Task.yield()
        }
        #expect(owned.todayReference > old)
        #expect(controlled.todayReference > old)
    }

    // The system posts these from background threads; a main-actor-isolated sink traps there.
    @Test(
        "System notifications posted off the main thread refresh Today without trapping",
        arguments: [
            Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange,
            .NSSystemClockDidChange,
        ])
    func backgroundNotifications(name: Notification.Name) async {
        let model = CalendarViewModel.test()
        let center = NotificationCenter()
        model.observeDayChanges(in: center)
        let old = Date(timeIntervalSince1970: 0)
        model.refreshToday(now: old)
        await Task.detached {
            center.post(name: name, object: nil)
        }.value
        for _ in 0..<100 {
            if model.todayReference != old { break }
            await Task.yield()
        }
        #expect(model.todayReference > old)
    }

    @Test(
        "Today rolls over at the configured calendar's midnight",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func configuredMidnight(identifier: Calendar.Identifier) throws {
        let iso = ISO8601DateFormatter()
        let morning = try #require(iso.date(from: "2026-11-20T05:00:00Z"))
        let midnight = try #require(iso.date(from: "2026-11-20T15:00:00Z"))
        let nextMidnight = try #require(iso.date(from: "2026-11-21T15:00:00Z"))
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let state = try CalendarState(
            calendar: calendar, currentDate: morning, dateRange: morning...morning)
        let model = CalendarViewModel(state: state)
        let scheduler = RolloverSchedule(now: morning)
        model.observeDayChanges(
            in: NotificationCenter(), now: { scheduler.now }, schedule: scheduler.schedule)

        #expect(scheduler.deadline == midnight)
        #expect(model.canGoToToday)
        #expect(
            model.monthSnapshot(for: model.visibleMonth)?.days.first(where: \.isToday)?.dayStart
                == calendar.startOfDay(for: morning))
        scheduler.now = midnight
        let fire = try #require(scheduler.fire)
        fire()

        #expect(model.todayReference == midnight)
        #expect(!model.canGoToToday)
        #expect(
            model.monthSnapshot(for: model.engine.month(containing: midnight))?.days.first(
                where: \.isToday)?.dayStart == midnight)
        #expect(model.state == state)
        #expect(scheduler.deadline == nextMidnight)
        #expect(scheduler.cancellations == 1)
    }

    @Test("An externally supplied time zone replaces the pending rollover")
    func changedTimeZoneReschedulesMidnight() throws {
        let iso = ISO8601DateFormatter()
        let morning = try #require(iso.date(from: "2026-03-08T05:00:00Z"))
        let utcMidnight = try #require(iso.date(from: "2026-03-09T00:00:00Z"))
        let newYorkMidnight = try #require(iso.date(from: "2026-03-09T04:00:00Z"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let initial = try CalendarState(calendar: calendar, currentDate: morning)
        let model = CalendarViewModel(
            state: initial,
            onAction: { _ in Issue.record("Clock refresh must not dispatch a host action") })
        let scheduler = RolloverSchedule(now: morning)
        model.observeDayChanges(
            in: NotificationCenter(), now: { scheduler.now }, schedule: scheduler.schedule)
        #expect(scheduler.deadline == utcMidnight)

        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let updated = try CalendarState(calendar: calendar, currentDate: morning)
        model.sync(state: updated) { _ in Issue.record("Time zone refresh must not dispatch") }

        #expect(scheduler.deadline == newYorkMidnight)
        #expect(scheduler.cancellations == 1)
        #expect(model.state == updated)
    }

    @Test("Today availability updates when the day leaves the allowed range")
    func availability() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let first = Date(timeIntervalSince1970: 1_749_945_600)
        let state = try CalendarState(
            calendar: calendar, currentDate: first, dateRange: first...first)
        let model = CalendarViewModel(state: state)
        model.refreshToday(now: first)
        #expect(model.canGoToToday)
        model.refreshToday(now: first.addingTimeInterval(86400))
        #expect(!model.canGoToToday)
    }
}
