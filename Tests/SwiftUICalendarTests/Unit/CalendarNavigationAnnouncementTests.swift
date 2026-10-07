import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Navigation announcements")
struct CalendarNavigationAnnouncementTests {
    @Test func rangeProgressAndCompletion() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 0)
        let end = start.addingTimeInterval(86400)
        let progress = try #require(
            CalendarAccessibility.rangeAnnouncement(.range(start, nil), calendar: calendar))
        #expect(progress.contains("Choose an end date"))
        let complete = try #require(
            CalendarAccessibility.rangeAnnouncement(.range(start, end), calendar: calendar))
        #expect(complete.contains("Selected range"))
        #expect(complete.contains("1970"))
        #expect(CalendarAccessibility.rangeAnnouncement(.single(start), calendar: calendar) == nil)
        #expect(
            CalendarAccessibility.rangeAnnouncement(.range(nil, nil), calendar: calendar) == nil)
    }
}
