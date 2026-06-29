import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar Header View Logic Tests")
struct CalendarHeaderViewLogicTests {

  @Test("Month header items use localized month symbols for the current year")
  func monthHeaderItemsUseLocalizedMonthSymbols() {
    let viewModel = CalendarViewModel.test(identifier: .hebrew)
    viewModel.currentDate = Calendar(identifier: .hebrew).date(
      from: DateComponents(year: 5785, month: 1, day: 1)
    )!

    let items = CalendarHeaderMonthView.monthItems(for: viewModel)

    #expect(items.count == viewModel.months(in: viewModel.currentYear).count)
    #expect(items.first?.id == 1)
    #expect(items.first?.title == viewModel.monthSymbol(for: 1, year: viewModel.currentYear))
    #expect(items.last?.id == 13)
    #expect(items.last?.title == viewModel.monthSymbol(for: 13, year: viewModel.currentYear))
  }

  @Test("Month header selection falls back to first item when current month is unavailable")
  func monthHeaderSelectionFallsBackToFirstItem() {
    let items = [
      MonthItem(id: 2, title: "Two"),
      MonthItem(id: 4, title: "Four"),
    ]
    let itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

    let selected = CalendarHeaderMonthView.selectedMonthItem(
      currentMonth: 3,
      itemsById: itemsById,
      items: items
    )

    #expect(selected.id == 2)
    #expect(selected.title == "Two")
  }

  @Test("Year header items cover the supported range and use locale formatting")
  func yearHeaderItemsCoverSupportedRange() {
    let viewModel = CalendarViewModel.test(identifier: .persian)

    let items = CalendarHeaderYearView.yearItems(for: viewModel)

    #expect(items.count == (viewModel.maxYear - viewModel.minYear + 1))
    #expect(items.first?.id == viewModel.minYear)
    #expect(items.last?.id == viewModel.maxYear)
    #expect(items.first?.title == NumberFormatter.formatYear(viewModel.minYear, locale: viewModel.locale))
    #expect(items.last?.title == NumberFormatter.formatYear(viewModel.maxYear, locale: viewModel.locale))
  }

  @Test("Year header selection falls back to first item when current year is unavailable")
  func yearHeaderSelectionFallsBackToFirstItem() {
    let items = [
      YearItem(id: 1403, title: "1403"),
      YearItem(id: 1404, title: "1404"),
    ]
    let itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

    let selected = CalendarHeaderYearView.selectedYearItem(
      currentYear: 1405,
      itemsById: itemsById,
      items: items
    )

    #expect(selected.id == 1403)
    #expect(selected.title == "1403")
  }

  @Test("Month header selection updates the view model month")
  func monthHeaderSelectionUpdatesViewModelMonth() {
    let viewModel = CalendarViewModel.test()

    CalendarHeaderMonthView.selectMonth(8, on: viewModel)

    #expect(viewModel.currentMonth == 8)
  }

  @Test("Month header previous navigation updates the model")
  func monthHeaderPreviousNavigationUpdatesModel() throws {
    let viewModel = CalendarViewModel.test()
    viewModel.currentMonth = 6
    viewModel.currentYear = 2025

    try CalendarHeaderMonthView.navigateToPreviousMonth(on: viewModel)

    #expect(viewModel.currentMonth == 5)
    #expect(viewModel.currentYear == 2025)
  }

  @Test("Month header next navigation updates the model")
  func monthHeaderNextNavigationUpdatesModel() throws {
    let viewModel = CalendarViewModel.test()
    viewModel.currentMonth = 6
    viewModel.currentYear = 2025

    try CalendarHeaderMonthView.navigateToNextMonth(on: viewModel)

    #expect(viewModel.currentMonth == 7)
    #expect(viewModel.currentYear == 2025)
  }

  @Test("Month header previous navigation throws at the lower bound")
  func monthHeaderPreviousNavigationThrowsAtLowerBound() {
    let viewModel = CalendarViewModel.test()
    viewModel.currentYear = 1900
    viewModel.currentMonth = 1

    #expect(throws: Error.self) {
      try CalendarHeaderMonthView.navigateToPreviousMonth(on: viewModel)
    }
  }

  @Test("Month header next navigation throws at the upper bound")
  func monthHeaderNextNavigationThrowsAtUpperBound() {
    let viewModel = CalendarViewModel.test()
    viewModel.currentYear = 2100
    viewModel.currentMonth = 12

    #expect(throws: Error.self) {
      try CalendarHeaderMonthView.navigateToNextMonth(on: viewModel)
    }
  }

  @Test("Year header selection updates the view model year")
  func yearHeaderSelectionUpdatesViewModelYear() {
    let viewModel = CalendarViewModel.test(identifier: .persian)
    let targetYear = viewModel.currentYear + 1

    CalendarHeaderYearView.selectYear(targetYear, on: viewModel)

    #expect(viewModel.currentYear == targetYear)
  }

  @Test("Year header previous navigation updates the model")
  func yearHeaderPreviousNavigationUpdatesModel() throws {
    let viewModel = CalendarViewModel.test()
    viewModel.currentYear = 2025
    viewModel.currentMonth = 6

    try CalendarHeaderYearView.navigateToPreviousYear(on: viewModel)

    #expect(viewModel.currentYear == 2024)
    #expect(viewModel.currentMonth == 6)
  }

  @Test("Year header next navigation updates the model")
  func yearHeaderNextNavigationUpdatesModel() throws {
    let viewModel = CalendarViewModel.test()
    viewModel.currentYear = 2025
    viewModel.currentMonth = 6

    try CalendarHeaderYearView.navigateToNextYear(on: viewModel)

    #expect(viewModel.currentYear == 2026)
    #expect(viewModel.currentMonth == 6)
  }

  @Test("Year header previous navigation throws at the lower bound")
  func yearHeaderPreviousNavigationThrowsAtLowerBound() {
    let viewModel = CalendarViewModel.test()
    viewModel.currentYear = 1900

    #expect(throws: Error.self) {
      try CalendarHeaderYearView.navigateToPreviousYear(on: viewModel)
    }
  }

  @Test("Year header next navigation throws at the upper bound")
  func yearHeaderNextNavigationThrowsAtUpperBound() {
    let viewModel = CalendarViewModel.test()
    viewModel.currentYear = 2100

    #expect(throws: Error.self) {
      try CalendarHeaderYearView.navigateToNextYear(on: viewModel)
    }
  }
}
