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

    var monthAccessibilityLabel: String {
        "Calendar.Navigation.Month.Selected".localized(with: selectedItem.wrappedValue.title)
    }

    var monthAccessibilityHint: String {
        "Calendar.Navigation.Month.ChangeHint".localized
    }

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
                .accessibilityLabel(monthAccessibilityLabel)
                .accessibilityHint(monthAccessibilityHint)
                .accessibilityIdentifier(CalendarAccessibilityID.monthButton)
        }
    }
}
