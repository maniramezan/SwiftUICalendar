import SwiftCommons
import SwiftUI

struct CalendarBodyVerticalView: View {
  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @State private var scrollPosition: MonthIdentifier?

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      LazyVStack(spacing: 24) {
        ForEach(monthItems) { item in
          VStack(spacing: 8) {
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
      .padding(.vertical, 8)
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
