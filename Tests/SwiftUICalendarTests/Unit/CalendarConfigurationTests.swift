import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar Configuration Tests")
struct CalendarConfigurationTests {
  @Test("default configuration is a fixed calendar with a header")
  func defaultConfiguration() {
    let configuration = CalendarConfiguration()

    #expect(configuration.scrollMode == .none)
    #expect(configuration.horizontalHeightMode == .sixRows)
    #expect(configuration.showsHeader)
    #expect(configuration.yearSelection == .init())
  }

  @Test("configuration is an independent value")
  func configurationHasValueSemantics() {
    var first = CalendarConfiguration(scrollMode: .horizontal)
    let second = first

    first.scrollMode = .vertical

    #expect(first.scrollMode == .vertical)
    #expect(second.scrollMode == .horizontal)
  }
}
