import OSLog
import SwiftUI

struct CalendarHeaderMonthView: View {
  @Environment(CalendarViewModel.self) var model

  private let logger = Logger.swiftUICalendar(for: Self.self)

  private var monthItems: [MonthItem] {
    model.months(in: model.currentYear).map {
      MonthItem(id: $0.month, title: model.monthSymbol(for: $0.month, year: $0.year))
    }
  }

  private var monthItemsById: [Int: MonthItem] {
    Dictionary(uniqueKeysWithValues: monthItems.map { ($0.id, $0) })
  }

  var body: some View {
    CalendarNavigationHeaderView(
      items: monthItems,
      selectedItem: Binding(
        get: {
          monthItemsById[model.currentMonth] ?? monthItems[0]
        },
        set: { newItem in
          model.currentMonth = newItem.id
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
