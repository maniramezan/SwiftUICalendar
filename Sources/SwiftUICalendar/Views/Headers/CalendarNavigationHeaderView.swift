import Components
import SwiftUI

struct CalendarNavigationHeaderView<Item: CalendarHeaderItem>: View {
  let items: [Item]
  let selectedItem: Binding<Item>
  let onPrevious: () -> Void
  let onNext: () -> Void
  var isPreviousDisabled: Bool = false
  var isNextDisabled: Bool = false

  var body: some View {
    CalendarHeaderChevronRow(
      onPrevious: onPrevious,
      onNext: onNext,
      isPreviousDisabled: isPreviousDisabled,
      isNextDisabled: isNextDisabled
    ) {
      MenuPicker(items: items, currentValue: selectedItem)
    }
  }
}
