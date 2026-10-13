import OSLog
import SwiftUI

struct CalendarHeaderMonthView: View {
    @Environment(CalendarViewModel.self) var model

    private let logger = Logger.swiftUICalendar(for: Self.self)

    /// Months of the year the header shows, which follows a vertical scroll before it settles.
    static func monthItems(for model: CalendarViewModel) -> [MonthItem] {
        model.months(in: model.headerYear).map {
            MonthItem(
                id: $0.month + ($0.identifier.isLeapMonth ? 100 : 0),
                title: model.monthSymbol(for: $0.identifier), month: $0.identifier)
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
        // Resolved once per body: this re-renders on every month a vertical scroll crosses.
        let items = Self.monthItems(for: model)
        let itemsById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let month = model.headerMonth
        CalendarNavigationHeaderView(
            items: items,
            selectedItem: Binding(
                get: {
                    Self.selectedMonthItem(
                        currentMonth: month.month + (month.isLeapMonth ? 100 : 0),
                        itemsById: itemsById,
                        items: items
                    )
                },
                set: { newItem in
                    if let month = newItem.month {
                        try? model.navigateInVisibleEra(toMonth: month)
                    }
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
