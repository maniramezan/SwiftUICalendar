import SwiftUI
import SwiftCommons
import OSLog

struct CalendarHeaderYearView: View {
    @Environment(CalendarViewModel.self) var model

    private let logger = Logger.swiftUICalendar(for: Self.self)

    private var yearItems: [YearItem] {
        (model.minYear...model.maxYear).map {
            YearItem(id: $0, title: NumberFormatter.formatYear($0, locale: model.locale))
        }
    }

    private var yearItemsById: [Int: YearItem] {
        Dictionary(uniqueKeysWithValues: yearItems.map { ($0.id, $0) })
    }

    var body: some View {
        CalendarNavigationHeaderView(
            items: yearItems,
            selectedItem: Binding(
                get: {
                    yearItemsById[model.currentYear] ?? yearItems[0]
                },
                set: { newItem in
                    model.currentYear = newItem.id
                }
            ),
            onPrevious: {
                do {
                    try model.updateYearToPreviousYear()
                } catch {
                    logger.error("Failed to navigate to previous year", error: error)
                }
            },
            onNext: {
                do {
                    try model.updateYearToNextYear()
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
