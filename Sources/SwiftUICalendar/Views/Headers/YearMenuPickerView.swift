import SwiftUI

/// A trigger button that presents a native dropdown menu listing every selectable year.
///
/// Built directly with SwiftUI's `Menu` rather than `MenuPicker` so `CalendarConfiguration.YearSelection.Style
/// .menu` always renders a dropdown regardless of item count, independent of `MenuPicker`'s
/// internal wheel-fallback threshold.
struct YearMenuPickerView: View {
  let items: [YearItem]
  @Binding var currentValue: YearItem

  var body: some View {
    Menu {
      ForEach(items) { item in
        Button {
          currentValue = item
        } label: {
          if item.id == currentValue.id {
            Label(item.title, systemImage: "checkmark")
          } else {
            Text(item.title)
          }
        }
      }
    } label: {
      Text(currentValue.title)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .allowsTightening(true)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    .menuIndicator(.hidden)
    .accessibilityLabel("Calendar.Navigation.Year.Selected".localized(with: currentValue.title))
    .accessibilityHint("Calendar.Navigation.Year.ChangeHint".localized)
  }
}

#Preview {
  @Previewable @State var currentValue = YearItem(id: 2026, title: "2026")
  YearMenuPickerView(
    items: (2000...2050).map { YearItem(id: $0, title: "\($0)") },
    currentValue: $currentValue
  )
}
