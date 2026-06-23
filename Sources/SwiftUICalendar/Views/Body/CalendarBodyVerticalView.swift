import SwiftCommons
import SwiftUI

struct CalendarBodyVerticalView: View {
  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.calendarMetrics) private var metrics
  @State private var scrollPosition: MonthIdentifier?

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      LazyVStack(spacing: metrics.monthSpacing) {
        ForEach(monthItems) { item in
          VStack(spacing: metrics.itemSpacing) {
            // Month and year header for each month
            HStack {
              Text(item.monthTitle)
                .font(typography.monthHeaderFont)
              Text(
                NumberFormatter.formatYear(
                  item.year,
                  locale: viewModel.locale)
              )
              .font(typography.monthHeaderFont)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CalendarBodyView(
              displayMonth: item.month,
              displayYear: item.year,
              hideOverflowDays: true,
              navigatesOnOverflowTap: false
            )
            .environment(theme)
            .environment(typography)
          }
          .id(item.id)
        }
      }
      // Required for `.scrollPosition(id:)` to report the visible month as the user scrolls.
      .scrollTargetLayout()
      .padding(.vertical, metrics.itemSpacing)
      .padding(.horizontal)
    }
    .scrollPosition(id: $scrollPosition, anchor: .top)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear {
      scrollPosition = currentMonthIdentifier
    }
    .onChange(of: viewModel.currentDate) { _, _ in
      withAnimation {
        scrollPosition = currentMonthIdentifier
      }
    }
    .onChange(of: scrollPosition) { _, newPosition in
      guard let position = newPosition,
        position.month != viewModel.currentMonth || position.year != viewModel.currentYear,
        let date = viewModel.firstDate(month: position.month, year: position.year)
      else { return }
      viewModel.currentDate = date
    }
  }

  private var monthItems: [VerticalMonthItem] {
    guard viewModel.minYear <= viewModel.maxYear else {
      return []
    }

    var items: [VerticalMonthItem] = []
    for year in viewModel.minYear...viewModel.maxYear {
      for metadata in viewModel.months(in: year) {
        let id = MonthIdentifier(month: metadata.month, year: year)
        items.append(
          VerticalMonthItem(
            id: id,
            month: metadata.month,
            year: year,
            monthTitle: viewModel.monthSymbol(for: metadata.month, year: year)
          )
        )
      }
    }
    return items
  }

  private var currentMonthIdentifier: MonthIdentifier {
    MonthIdentifier(month: viewModel.currentMonth, year: viewModel.currentYear)
  }
}

#Preview {
  CalendarBodyVerticalView()
    .environment(CalendarViewModel.test(identifier: .persian, selection: .range(Date(), nil)))
    .environment(Theme.default)
    .environment(Typography.default)
}

private struct MonthIdentifier: Hashable {
  let month: Int
  let year: Int
}

private struct VerticalMonthItem: Identifiable {
  let id: MonthIdentifier
  let month: Int
  let year: Int
  let monthTitle: String
}
