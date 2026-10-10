import Components
import SwiftUI
import SwiftUICalendarAccessibility

/// A trigger button that presents a sheet containing a wheel-style year picker.
///
/// The iOS sheet retains its calendar-specific Done action, which the shared wheel presentation
/// cannot customize. Outside iOS, the shared wheel preference falls back to a native dropdown.
struct YearWheelPickerView: View {
    @Environment(\.calendarMetrics) private var metrics
    let items: [YearItem]
    @Binding var currentValue: YearItem

    @State private var isPresented = false

    var body: some View {
        #if os(iOS)
        Button(action: { isPresented = true }) {
            Text(currentValue.title)
                .lineLimit(1)
                // A year never wraps; it asks for its natural width so the header reflows or
                // overflows instead of truncating it.
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, metrics.controlPadding)
                .padding(.vertical, metrics.tightPadding)
                .frame(minWidth: metrics.minimumHitTarget, minHeight: metrics.minimumHitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Calendar.Navigation.Year.Selected".localized(with: currentValue.title)
        )
        .accessibilityHint("Calendar.Navigation.Year.ChangeHint".localized)
        .accessibilityIdentifier(CalendarAccessibilityID.yearButton)
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                Picker("", selection: $currentValue) {
                    ForEach(items) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.wheel)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Calendar.Done".localized) {
                            isPresented = false
                        }
                        .accessibilityIdentifier(CalendarAccessibilityID.yearPickerDoneButton)
                    }
                }
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
        #else
        // The wheel picker style is unavailable outside iOS; fall back to a native dropdown menu so
        // the control is still usable.
        MenuPicker(items: items, currentValue: $currentValue, preferredStyle: .wheel)
            .accessibilityLabel(
                "Calendar.Navigation.Year.Selected".localized(with: currentValue.title)
            )
            .accessibilityHint("Calendar.Navigation.Year.ChangeHint".localized)
            .accessibilityIdentifier(CalendarAccessibilityID.yearButton)
        #endif
    }
}

#Preview {
    @Previewable @State var currentValue = YearItem(id: 2026, title: "2026")
    YearWheelPickerView(
        items: (2000...2050).map { YearItem(id: $0, title: "\($0)") },
        currentValue: $currentValue
    )
}
