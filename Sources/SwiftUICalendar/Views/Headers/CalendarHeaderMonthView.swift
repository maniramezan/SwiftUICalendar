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
          try? model.navigate(toMonth: newItem.id, year: model.currentYear)
        }
      ),
      onPrevious: {
        do {
          try model.updateMonthToPreviousMonth()
        } catch {
          logger.error("Failed to navigate to previous month", error: error)
        }
      },
      onNext: {
        do {
          try model.updateMonthToNextMonth()
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
