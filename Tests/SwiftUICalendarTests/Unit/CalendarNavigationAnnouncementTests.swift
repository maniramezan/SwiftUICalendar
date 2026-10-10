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

    @Test func monthAnnouncementSkipsTheFirstMonthSeen() {
        let tracker = MonthAnnouncementTracker()
        let june = MonthIdentifier(month: 6, year: 2025)
        let july = MonthIdentifier(month: 7, year: 2025)
        // The month on screen when the calendar appears is context, not navigation.
        #expect(!tracker.shouldAnnounce(june))
        #expect(!tracker.shouldAnnounce(june))
        #expect(tracker.shouldAnnounce(july))
        tracker.markAnnounced(july)
        #expect(!tracker.shouldAnnounce(july))
        // Returning to a previous month is a change again.
        #expect(tracker.shouldAnnounce(june))
    }
}
