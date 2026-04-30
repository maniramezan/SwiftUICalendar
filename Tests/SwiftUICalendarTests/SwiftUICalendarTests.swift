import XCTest

@testable import SwiftUICalendar

final class SwiftUICalendarTests: XCTestCase {
  func testMonthMetadataForLeapYearFebruary() throws {
    let model = CalendarViewModel(calendarIdentifier: .gregorian)
    let metadata = model.monthMetadata(month: 2, year: 2024)

    XCTAssertNotNil(metadata)
    XCTAssertEqual(metadata?.month, 2)
    XCTAssertEqual(metadata?.year, 2024)
    XCTAssertEqual(metadata?.numberOfDays, 29)
  }

  func testMonthMetadataForNonLeapYearFebruary() throws {
    let model = CalendarViewModel(calendarIdentifier: .gregorian)
    let metadata = model.monthMetadata(month: 2, year: 2023)

    XCTAssertNotNil(metadata)
    XCTAssertEqual(metadata?.month, 2)
    XCTAssertEqual(metadata?.year, 2023)
    XCTAssertEqual(metadata?.numberOfDays, 28)
  }
}
