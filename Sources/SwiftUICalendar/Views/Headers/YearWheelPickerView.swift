import SwiftUI

/// A trigger button that presents a sheet containing a wheel-style year picker.
///
/// Unlike `MenuPicker`, this always uses the wheel presentation regardless of how many years are
/// offered, so `Theme.YearSelection.Style.wheel` behaves consistently even when a developer
/// restricts the selectable range to a small number of years.
struct YearWheelPickerView: View {
  let items: [YearItem]
  @Binding var currentValue: YearItem

  @State private var isPresented = false

  var body: some View {
    #if os(iOS)
      Button(action: { isPresented = true }) {
        Text(currentValue.title)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .allowsTightening(true)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Calendar.Navigation.Year.Selected".localized(with: currentValue.title))
      .accessibilityHint("Calendar.Navigation.Year.ChangeHint".localized)
      .sheet(isPresented: $isPresented) {
        Picker("", selection: $currentValue) {
          ForEach(items) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.wheel)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
      }
    #else
      // The wheel picker style is unavailable outside iOS; fall back to a native dropdown menu so
      // the control is still usable.
      YearMenuPickerView(items: items, currentValue: $currentValue)
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
