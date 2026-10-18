import Components
import SwiftUI
import SwiftUICalendarAccessibility

struct CalendarNavigationHeaderView<Item: CalendarHeaderItem>: View {
    @Environment(\.calendarMetrics) private var metrics

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
            Menu {
                Picker(selection: selectedItem) {
                    ForEach(items) { item in
                        Text(item.title).tag(item)
                    }
                } label: {
                    Text(selectedItem.wrappedValue.title)
                }
                .pickerStyle(.inline)
            } label: {
                ZStack {
                    // Measure every label in the inherited font, including proportional digits
                    // and localized month names, so navigation keeps the trigger width stable.
                    ForEach(items) { item in
                        Text(item.title)
                            .hidden()
                    }
                    Text(selectedItem.wrappedValue.title)
                }
                .fixedSize()
                .frame(minWidth: metrics.minimumHitTarget, minHeight: metrics.minimumHitTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(monthAccessibilityLabel)
            .accessibilityHint(monthAccessibilityHint)
            .accessibilityIdentifier(CalendarAccessibilityID.monthButton)
        }
    }
}
