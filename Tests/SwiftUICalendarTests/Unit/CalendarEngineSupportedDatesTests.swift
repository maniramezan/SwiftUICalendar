import Foundation
import Testing

@testable import SwiftUICalendar

@Suite("CalendarEngine Supported Dates Tests")
struct CalendarEngineSupportedDatesTests {

  private func engine(timeZoneIdentifier: String) throws -> CalendarEngine {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: timeZoneIdentifier))
    return CalendarEngine(calendar: calendar)
  }

  @Test("repeated reads return an identical range")
  func repeatedReadsAreIdentical() throws {
    let engine = try engine(timeZoneIdentifier: "UTC")

    #expect(engine.supportedDates == engine.supportedDates)
  }

  @Test("the range spans 1900 through the end of 2100")
  func rangeSpansSupportedYears() throws {
    let engine = try engine(timeZoneIdentifier: "UTC")
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = try #require(TimeZone(identifier: "UTC"))

    let start = try #require(gregorian.date(from: DateComponents(year: 1900, month: 1, day: 1)))
    let end = try #require(gregorian.date(from: DateComponents(year: 2101, month: 1, day: 1)))

    #expect(engine.supportedDates.lowerBound == start)
    #expect(engine.supportedDates.upperBound == end)
  }

  @Test("each time zone resolves its own range")
  func timeZonesResolveDistinctRanges() throws {
    let utc = try engine(timeZoneIdentifier: "UTC")
    let tokyo = try engine(timeZoneIdentifier: "Asia/Tokyo")

    #expect(utc.supportedDates.lowerBound != tokyo.supportedDates.lowerBound)
  }

  @Test("containment matches the documented boundaries")
  func containmentMatchesBoundaries() throws {
    let engine = try engine(timeZoneIdentifier: "UTC")

    #expect(engine.contains(engine.supportedDates.lowerBound))
    #expect(!engine.contains(engine.supportedDates.lowerBound.addingTimeInterval(-1)))
    #expect(engine.contains(engine.supportedDates.upperBound.addingTimeInterval(-1)))
    #expect(!engine.contains(engine.supportedDates.upperBound))
  }
}
