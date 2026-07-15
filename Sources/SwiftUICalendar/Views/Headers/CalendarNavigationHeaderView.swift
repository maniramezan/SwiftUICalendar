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
      // NOTE: intended to pass `preferredStyle: .menu` here so year matches month's presentation
      // regardless of item count (year's ~200 items otherwise silently fall back to a wheel-sheet
      // once they cross MenuPicker's internal 30-item threshold). That parameter requires an
      // unreleased SwiftUIComponents change (see MenuPicker.swift's `PresentationStyle`) that
      // isn't in the pinned remote package version yet, so it's reverted here to keep the build
      // green until that's published. See conversation for the plan to ship it properly.
      MenuPicker(items: items, currentValue: selectedItem)
    }
  }
}
