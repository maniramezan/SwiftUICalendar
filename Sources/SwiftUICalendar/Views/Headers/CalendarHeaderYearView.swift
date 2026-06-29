import OSLog
import SwiftCommons
import SwiftUI

struct CalendarHeaderYearView: View {
  @Environment(CalendarViewModel.self) var model

  private let logger = Logger.swiftUICalendar(for: Self.self)

  private var yearItems: [YearItem] {
    Self.yearItems(for: model)
  }

  private var yearItemsById: [Int: YearItem] {
    Dictionary(uniqueKeysWithValues: yearItems.map { ($0.id, $0) })
  }

  static func yearItems(for model: CalendarViewModel) -> [YearItem] {
    (model.minYear...model.maxYear).map {
      YearItem(id: $0, title: NumberFormatter.formatYear($0, locale: model.locale))
    }
  }

  static func selectedYearItem(
    currentYear: Int,
    itemsById: [Int: YearItem],
    items: [YearItem]
  ) -> YearItem {
    itemsById[currentYear] ?? items[0]
  }

  static func selectYear(_ year: Int, on model: CalendarViewModel) {
    model.currentYear = year
  }

  static func navigateToPreviousYear(on model: CalendarViewModel) throws {
    try model.updateYearToPreviousYear()
  }

  static func navigateToNextYear(on model: CalendarViewModel) throws {
    try model.updateYearToNextYear()
  }

  var body: some View {
    CalendarNavigationHeaderView(
      items: yearItems,
      selectedItem: Binding(
        get: {
          Self.selectedYearItem(
            currentYear: model.currentYear,
            itemsById: yearItemsById,
            items: yearItems
          )
        },
        set: { newItem in
          Self.selectYear(newItem.id, on: model)
        }
      ),
      onPrevious: {
        do {
          try Self.navigateToPreviousYear(on: model)
        } catch {
          logger.error("Failed to navigate to previous year", error: error)
        }
      },
      onNext: {
        do {
          try Self.navigateToNextYear(on: model)
        } catch {
          logger.error("Failed to navigate to next year", error: error)
        }
      },
      isPreviousDisabled: !model.canNavigateToPreviousYear,
      isNextDisabled: !model.canNavigateToNextYear
    )
  }
}

#Preview {
  CalendarHeaderYearView()
    .environment(CalendarViewModel.test(identifier: .persian))
}
