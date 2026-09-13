import Foundation
import Testing

@testable import SwiftUICalendar

@Suite("CalendarSelection Matcher Tests")
struct CalendarSelectionMatcherTests {
  private let calendar = Calendar(identifier: .gregorian)

  private func day(_ day: Int) throws -> Date {
    try #require(calendar.date(from: DateComponents(year: 2025, month: 6, day: day)))
  }

  @Test("single selection matches only the selected day")
  func singleSelectionMatchesOneDay() throws {
    let selected = try day(10)
    let matches = CalendarSelection.single(selected).matcher(in: calendar)

    #expect(matches(selected))
    #expect(!matches(try day(11)))
  }

  @Test("an empty single selection matches nothing")
  func emptySingleSelectionMatchesNothing() throws {
    let matches = CalendarSelection.single(nil).matcher(in: calendar)

    #expect(!matches(try day(10)))
  }

  @Test("a range matches its bounds and everything between")
  func rangeMatchesInclusiveBounds() throws {
    let matches = CalendarSelection.range(try day(10), try day(13)).matcher(in: calendar)

    #expect(matches(try day(10)))
    #expect(matches(try day(12)))
    #expect(matches(try day(13)))
    #expect(!matches(try day(9)))
    #expect(!matches(try day(14)))
  }

  @Test("an open range matches only its start")
  func openRangeMatchesStartOnly() throws {
    let matches = CalendarSelection.range(try day(10), nil).matcher(in: calendar)

    #expect(matches(try day(10)))
    #expect(!matches(try day(11)))
  }

  @Test("an unset range matches nothing")
  func unsetRangeMatchesNothing() throws {
    let matches = CalendarSelection.range(nil, nil).matcher(in: calendar)

    #expect(!matches(try day(10)))
  }

  @Test("a reversed range is normalized before matching")
  func reversedRangeIsNormalized() throws {
    let matches = CalendarSelection.range(try day(13), try day(10)).matcher(in: calendar)

    #expect(matches(try day(11)))
  }

  @Test("multiple selection matches each member")
  func multipleSelectionMatchesEachMember() throws {
    let matches = CalendarSelection.multiple([try day(3), try day(20)]).matcher(in: calendar)

    #expect(matches(try day(3)))
    #expect(matches(try day(20)))
    #expect(!matches(try day(4)))
  }

  @Test("the matcher agrees with contains for every selection mode")
  func matcherAgreesWithContains() throws {
    let selections: [CalendarSelection] = [
      .single(try day(10)),
      .single(nil),
      .range(try day(10), try day(13)),
      .range(try day(10), nil),
      .range(nil, nil),
      .multiple([try day(3), try day(20)]),
      .multiple([]),
    ]

    for selection in selections {
      for number in 1...30 {
        let date = try day(number)
        #expect(
          selection.matcher(in: calendar)(calendar.startOfDay(for: date))
            == selection.contains(date, in: calendar))
      }
    }
  }

  @Test("a mid-day timestamp still matches its selected day")
  func midDayTimestampMatches() throws {
    let selected = try day(10)
    let noon = try #require(calendar.date(byAdding: .hour, value: 12, to: selected))

    #expect(CalendarSelection.single(selected).contains(noon, in: calendar))
  }
}
