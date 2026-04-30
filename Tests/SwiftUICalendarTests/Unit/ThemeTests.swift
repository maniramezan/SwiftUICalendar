import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Theme Tests")
struct ThemeTests {

  @Test("Theme.default returns independent instances")
  func defaultReturnsIndependentInstances() {
    let first = Theme.default
    first.scrollMode = .horizontal
    first.horizontalHeightMode = .hugContent
    first.day.emptyDayBorderColorWidth = 3

    let second = Theme.default

    #expect(second.scrollMode == .none)
    #expect(second.horizontalHeightMode == .sixRows)
    #expect(second.day.emptyDayBorderColorWidth == 0)
  }
}
