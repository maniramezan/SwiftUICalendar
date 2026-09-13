import Foundation
import SwiftCommons
import Testing

@testable import SwiftUICalendar

@Suite @MainActor
struct CalendarArithmeticIntegrationTests {
  @Test func sharedIdentityPreservesSourceCompatibility() {
    let shared = SwiftCommons.MonthIdentifier(month: 6, year: 2025)
    let original: SwiftUICalendar.MonthIdentifier = shared
    let model = CalendarViewModel.test()
    #expect(model.engine.start(of: original) != nil)
  }

  @Test func widgetRetainsBoundsWhileSharedArithmeticIsUnrestricted() throws {
    let model = CalendarViewModel.test()
    let arithmetic = CalendarArithmetic(calendar: model.engine.calendar)
    let last = model.engine.month(
      containing: model.engine.supportedDates.upperBound.addingTimeInterval(-1))
    #expect(arithmetic.month(offset: 1, from: last) != nil)
    #expect(model.engine.month(offset: 1, from: last) == nil)
    let first = model.engine.month(containing: model.engine.supportedDates.lowerBound)
    #expect(arithmetic.month(offset: -1, from: first) != nil)
    #expect(model.engine.month(offset: -1, from: first) == nil)
  }
}
