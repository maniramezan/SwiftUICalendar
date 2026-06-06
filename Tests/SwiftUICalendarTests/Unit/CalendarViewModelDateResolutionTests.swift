import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Date Resolution Tests")
struct CalendarViewModelDateResolutionTests {

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!
  }

  @Test("date(for:month:year:): resolves to the requested day components")
  func dateForExplicitComponentsResolves() throws {
    let vm = CalendarViewModel.test()
    let date = try #require(vm.date(for: 15, month: 6, year: 2025))
    let cal = Calendar(identifier: .gregorian)
    #expect(cal.component(.day, from: date) == 15)
    #expect(cal.component(.month, from: date) == 6)
    #expect(cal.component(.year, from: date) == 2025)
  }

  @Test("date(for:): resolves a day in the currently displayed month")
  func dateForCurrentMonthResolves() throws {
    let vm = CalendarViewModel.test()
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    let date = try #require(vm.date(for: 10))
    let cal = Calendar(identifier: .gregorian)
    #expect(cal.component(.day, from: date) == 10)
    #expect(cal.component(.month, from: date) == 6)
    #expect(cal.component(.year, from: date) == 2025)
  }

  @Test("isSelected(_:): returns false safely when no selection is set")
  func isSelectedDayReturnsFalseWithoutSelection() {
    let vm = CalendarViewModel.test(selection: .single(nil))
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    #expect(!vm.isSelected(10))
  }

  @Test("isSelected(_:): reflects a matching single selection in the current month")
  func isSelectedDayMatchesSingleSelection() {
    let selected = makeDate(year: 2025, month: 6, day: 10)
    let vm = CalendarViewModel.test(selection: .single(selected))
    vm.currentDate = makeDate(year: 2025, month: 6, day: 1)
    #expect(vm.isSelected(10))
    #expect(!vm.isSelected(11))
  }
}
