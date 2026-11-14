import Foundation
import Observation
import Synchronization
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar day rollover")
struct CalendarDayRolloverTests {
    @Test(
        "Midnight moves Today without navigating or changing selection",
        arguments: [Calendar.Identifier.gregorian, .persian])
    func midnight(identifier: Calendar.Identifier) throws {
        let model = CalendarViewModel.test(identifier: identifier)
        let calendar = model.engine.calendar
        let first = calendar.startOfDay(for: model.currentDate)
        let next = try #require(calendar.date(byAdding: .day, value: 1, to: first))
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
            model.monthSnapshot(for: model.visibleMonth)?.days.first(where: \.isToday)?.dayStart
                == next)
        #expect(model.isToday(calendar.component(.day, from: next)))
        #expect(model.state == state)
    }

    @Test(
        "System notifications invalidate locally and externally owned projections",
        arguments: [Notification.Name.NSCalendarDayChanged, .NSSystemTimeZoneDidChange])
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
