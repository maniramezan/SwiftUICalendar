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
    #expect(
      items.first?.title == NumberFormatter.formatYear(viewModel.minYear, locale: viewModel.locale))
    #expect(
      items.last?.title == NumberFormatter.formatYear(viewModel.maxYear, locale: viewModel.locale))
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
}
