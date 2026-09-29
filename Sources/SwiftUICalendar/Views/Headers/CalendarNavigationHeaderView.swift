import Components
import SwiftUI
import SwiftUICalendarAccessibility

struct CalendarNavigationHeaderView<Item: CalendarHeaderItem>: View {
    let items: [Item]
    let selectedItem: Binding<Item>
    let onPrevious: () -> Void
    let onNext: () -> Void
    var isPreviousDisabled: Bool = false
    var isNextDisabled: Bool = false

    var body: some View {
        CalendarHeaderChevronRow(
            previousIdentifier: CalendarAccessibilityID.previousMonthButton,
            nextIdentifier: CalendarAccessibilityID.nextMonthButton,
            onPrevious: onPrevious,
            onNext: onNext,
            isPreviousDisabled: isPreviousDisabled,
            isNextDisabled: isNextDisabled
        ) {
            MenuPicker(items: items, currentValue: selectedItem)
                .accessibilityIdentifier(CalendarAccessibilityID.monthButton)
        }
    }
}
