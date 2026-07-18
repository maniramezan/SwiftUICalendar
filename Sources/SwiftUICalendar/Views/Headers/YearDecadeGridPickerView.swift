import SwiftUI

/// A trigger button that presents a popover with a 3x3 grid of selectable years.
///
/// Each page shows nine consecutive years. Use the chevrons in the popover's navigation row to
/// page nine years at a time; paging is clamped to the supplied `minYear`/`maxYear` bounds.
struct YearDecadeGridPickerView: View {
  let minYear: Int
  let maxYear: Int
  let formatTitle: (Int) -> String
  @Binding var currentValue: YearItem

  @State private var isPresented = false
  @State private var pageStart: Int

  init(
    minYear: Int,
    maxYear: Int,
    currentValue: Binding<YearItem>,
    formatTitle: @escaping (Int) -> String
  ) {
    self.minYear = minYear
    self.maxYear = maxYear
    self._currentValue = currentValue
    self.formatTitle = formatTitle
    self._pageStart = State(
      initialValue: YearDecadeGrid.clampedPageStart(
        YearDecadeGrid.pageStart(for: currentValue.wrappedValue.id),
        minYear: minYear,
        maxYear: maxYear
      )
    )
  }

  var body: some View {
    Button(action: {
      pageStart = YearDecadeGrid.clampedPageStart(
        YearDecadeGrid.pageStart(for: currentValue.id),
        minYear: minYear,
        maxYear: maxYear
      )
      isPresented = true
    }) {
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
    .popover(isPresented: $isPresented) {
      YearDecadeGridPopoverContent(
        minYear: minYear,
        maxYear: maxYear,
        pageStart: $pageStart,
        currentValue: $currentValue,
        formatTitle: formatTitle,
        isPresented: $isPresented
      )
    }
  }
}

/// The popover body for `YearDecadeGridPickerView`: a paging header plus a 3x3 grid of years.
/// Internal (not private) so hosting tests can render the grid without presenting a popover.
struct YearDecadeGridPopoverContent: View {
  let minYear: Int
  let maxYear: Int
  @Binding var pageStart: Int
  @Binding var currentValue: YearItem
  let formatTitle: (Int) -> String
  @Binding var isPresented: Bool

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        Button(action: pageBackward) {
          Image(systemName: "chevron.backward")
            .font(.body.weight(.semibold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Calendar.Navigation.Previous".localized)
        .disabled(!YearDecadeGrid.canPageBackward(from: pageStart, minYear: minYear))

        Spacer()

        Text(YearDecadeGrid.rangeLabel(pageStart: pageStart))
          .font(.headline)

        Spacer()

        Button(action: pageForward) {
          Image(systemName: "chevron.forward")
            .font(.body.weight(.semibold))
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Calendar.Navigation.Next".localized)
        .disabled(!YearDecadeGrid.canPageForward(from: pageStart, maxYear: maxYear))
      }

      LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
        ForEach(YearDecadeGrid.years(pageStart: pageStart), id: \.self) { year in
          YearDecadeGridCell(
            year: year,
            minYear: minYear,
            maxYear: maxYear,
            isSelected: year == currentValue.id,
            formatTitle: formatTitle,
            onSelect: {
              currentValue = YearItem(id: year, title: formatTitle(year))
              isPresented = false
            }
          )
        }
      }
    }
    .padding()
    .frame(width: 220)
  }

  private func pageBackward() {
    pageStart = YearDecadeGrid.adjacentPageStart(
      from: pageStart, by: -1, minYear: minYear, maxYear: maxYear)
  }

  private func pageForward() {
    pageStart = YearDecadeGrid.adjacentPageStart(
      from: pageStart, by: 1, minYear: minYear, maxYear: maxYear)
  }
}

/// A single selectable year cell within the decade grid popover.
private struct YearDecadeGridCell: View {
  let year: Int
  let minYear: Int
  let maxYear: Int
  let isSelected: Bool
  let formatTitle: (Int) -> String
  let onSelect: () -> Void

  private var isSelectable: Bool {
    (minYear...maxYear).contains(year)
  }

  var body: some View {
    Button(action: onSelect) {
      Text(formatTitle(year))
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
    .disabled(!isSelectable)
    .opacity(isSelectable ? 1 : 0.3)
  }
}

#Preview {
  @Previewable @State var currentValue = YearItem(id: 2026, title: "2026")
  YearDecadeGridPickerView(
    minYear: 1900,
    maxYear: 2100,
    currentValue: $currentValue,
    formatTitle: { "\($0)" }
  )
}
