import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarViewModel Boundary Navigation Tests")
struct CalendarViewModelBoundaryTests {

  // MARK: - updateMonth(byAdding:) out of range

  @Test("updateMonth byAdding far beyond the supported range throws")
  func updateMonthBeyondRangeThrows() {
    let vm = CalendarViewModel.test()
    #expect(throws: (any Error).self) { try vm.updateMonth(byAdding: 100_000) }
    #expect(throws: (any Error).self) { try vm.updateMonth(byAdding: -100_000) }
  }

  @Test("updateMonth byAdding a small in-range amount succeeds")
  func updateMonthInRangeSucceeds() throws {
    let vm = CalendarViewModel.test()
    try vm.updateMonth(byAdding: 1)
  }

  // MARK: - Next/previous month at the year boundary

  @Test("updateMonthToNextMonth throws at the maximum supported year")
  func nextMonthAtMaxYearThrows() throws {
    let vm = CalendarViewModel.test()
    let boundary = try #require(vm.firstDate(month: 12, year: vm.maxYear))
    vm.currentDate = boundary
    #expect(throws: (any Error).self) { try vm.updateMonthToNextMonth() }
  }

  @Test("updateMonthToPreviousMonth throws at the minimum supported year")
  func previousMonthAtMinYearThrows() throws {
    let vm = CalendarViewModel.test()
    let boundary = try #require(vm.firstDate(month: 1, year: vm.minYear))
    vm.currentDate = boundary
    #expect(throws: (any Error).self) { try vm.updateMonthToPreviousMonth() }
  }

  // MARK: - canNavigate flags at the boundary

  @Test("Cannot navigate to the next year at the maximum supported year")
  func cannotNavigateNextYearAtMax() throws {
    let vm = CalendarViewModel.test()
    let boundary = try #require(vm.firstDate(month: 1, year: vm.maxYear))
    vm.currentDate = boundary
    #expect(vm.canNavigateToNextYear == false)
  }

  @Test("Cannot navigate to the previous year at the minimum supported year")
  func cannotNavigatePreviousYearAtMin() throws {
    let vm = CalendarViewModel.test()
    let boundary = try #require(vm.firstDate(month: 1, year: vm.minYear))
    vm.currentDate = boundary
    #expect(vm.canNavigateToPreviousYear == false)
  }
}
