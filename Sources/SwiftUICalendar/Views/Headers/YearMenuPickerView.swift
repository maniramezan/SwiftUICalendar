import Components
import SwiftUI
import SwiftUICalendarAccessibility

/// A trigger button that presents a native dropdown menu listing every selectable year.
///
/// Uses the shared picker's explicit menu presentation so even a long year list stays a dropdown.
struct YearMenuPickerView: View {
    let items: [YearItem]
    @Binding var currentValue: YearItem

    var body: some View {
        MenuPicker(items: items, currentValue: $currentValue, preferredStyle: .menu)
            .accessibilityLabel(
                "Calendar.Navigation.Year.Selected".localized(with: currentValue.title)
            )
            .accessibilityHint("Calendar.Navigation.Year.ChangeHint".localized)
            .accessibilityIdentifier(CalendarAccessibilityID.yearButton)
    }
}

#Preview {
    @Previewable @State var currentValue = YearItem(id: 2026, title: "2026")
    YearMenuPickerView(
        items: (2000...2050).map { YearItem(id: $0, title: "\($0)") },
        currentValue: $currentValue
    )
}
