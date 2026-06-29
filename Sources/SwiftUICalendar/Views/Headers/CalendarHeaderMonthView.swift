import OSLog
import SwiftUI

struct CalendarHeaderMonthView: View {
  @Environment(CalendarViewModel.self) var model

  private let logger = Logger.swiftUICalendar(for: Self.self)

  private var monthItems: [MonthItem] {
    Self.monthItems(for: model)
  }

  private var monthItemsById: [Int: MonthItem] {
    Dictionary(uniqueKeysWithValues: monthItems.map { ($0.id, $0) })
  }

  static func monthItems(for model: CalendarViewModel) -> [MonthItem] {
    model.months(in: model.currentYear).map {
      MonthItem(id: $0.month, title: model.monthSymbol(for: $0.month, year: $0.year))
    }
  }

  static func selectedMonthItem(
    currentMonth: Int,
    itemsById: [Int: MonthItem],
    items: [MonthItem]
  ) -> MonthItem {
    itemsById[currentMonth] ?? items[0]
  }

  static func selectMonth(_ month: Int, on model: CalendarViewModel) {
    model.currentMonth = month
  }

  static func navigateToPreviousMonth(on model: CalendarViewModel) throws {
    try model.updateMonthToPreviousMonth()
  }

  static func navigateToNextMonth(on model: CalendarViewModel) throws {
    try model.updateMonthToNextMonth()
  }

  var body: some View {
    CalendarNavigationHeaderView(
      items: monthItems,
      selectedItem: Binding(
        get: {
          Self.selectedMonthItem(
            currentMonth: model.currentMonth,
            itemsById: monthItemsById,
            items: monthItems
          )
        },
        set: { newItem in
          Self.selectMonth(newItem.id, on: model)
        }
      ),
      onPrevious: {
        do {
          try Self.navigateToPreviousMonth(on: model)
        } catch {
          logger.error("Failed to navigate to previous month", error: error)
        }
      },
      onNext: {
        do {
          try Self.navigateToNextMonth(on: model)
        } catch {
          logger.error("Failed to navigate to next month", error: error)
        }
      },
      isPreviousDisabled: !model.canNavigateToPreviousMonth,
      isNextDisabled: !model.canNavigateToNextMonth
    )
  }
}

#Preview {
  CalendarHeaderMonthView()
    .environment(CalendarViewModel.test())
}
