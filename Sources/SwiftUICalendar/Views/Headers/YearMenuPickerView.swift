import Components
import SwiftUI
import SwiftUICalendarAccessibility

/// A trigger button that presents a native dropdown menu listing every selectable year.
///
/// Inherits the calendar header font and keeps even a long year list in a dropdown.
struct YearMenuPickerView: View {
    @Environment(\.calendarMetrics) private var metrics

    let items: [YearItem]
    @Binding var currentValue: YearItem

    var body: some View {
        Menu {
            Picker(selection: $currentValue) {
                ForEach(items) { item in
                    Text(item.title).tag(item)
                }
            } label: {
                Text(currentValue.title)
            }
            .pickerStyle(.inline)
        } label: {
            Text(currentValue.title)
                .fixedSize()
                .frame(minWidth: metrics.minimumHitTarget, minHeight: metrics.minimumHitTarget)
        }
        .buttonStyle(.plain)
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
