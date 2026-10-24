import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Shared month geometry")
struct CalendarMonthGeometryTests {
    @Test(arguments: [Calendar.Identifier.gregorian, .persian])
    func respectsWeekStartsAndMonthMembership(identifier: Calendar.Identifier) throws {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        calendar.firstWeekday = 2
        let engine = CalendarEngine(calendar: calendar)
        let month = engine.month(containing: Date(timeIntervalSince1970: 1_748_736_000))
        let geometry = try #require(
            CalendarRenderCache.computeMonthGeometry(
                for: month, calendar: calendar, engine: engine))
        let interval = try #require(engine.interval(of: month))

        #expect(calendar.component(.weekday, from: try #require(geometry.days.first).date) == 2)
        #expect(geometry.days.count.isMultiple(of: 7))
        #expect(
            geometry.days.allSatisfy {
                $0.isInDisplayedMonth == ($0.date >= interval.start && $0.date < interval.end)
            })
        #expect(geometry.days.allSatisfy { $0.date == $0.dayStart })
    }

    @Test func eraSegmentDoesNotMarkFollowingEraAsDisplayedMonth() throws {
        var calendar = Calendar(identifier: .japanese)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        calendar.firstWeekday = 2
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let date = try #require(gregorian.date(from: DateComponents(year: 1989, month: 1, day: 1)))
        let engine = CalendarEngine(calendar: calendar)
        let month = engine.month(containing: date)
        let geometry = try #require(
            CalendarRenderCache.computeMonthGeometry(
                for: month, calendar: calendar, engine: engine))
        let displayed = geometry.days.filter(\.isInDisplayedMonth)

        #expect(geometry.days.count == 14)
        #expect(displayed.map(\.day) == Array(1...7))
        #expect(geometry.days.last?.isInDisplayedMonth == false)
    }
}
