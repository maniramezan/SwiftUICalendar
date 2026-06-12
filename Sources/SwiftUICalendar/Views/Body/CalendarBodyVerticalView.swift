import SwiftCommons
import SwiftUI

struct CalendarBodyVerticalView: View {
  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @State private var hasScrolledToCurrentMonth = false

  var body: some View {
    ScrollViewReader { reader in
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
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .onAppear {
        // Delay scroll to ensure content is laid out
        if !hasScrolledToCurrentMonth {
          DispatchQueue.main.async {
            scrollToCurrentMonth(using: reader, animated: false)
          }
        }
      }
      .onChange(of: viewModel.currentDate) { _, _ in
        DispatchQueue.main.async {
          scrollToCurrentMonth(using: reader, animated: true)
        }
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

  private func scrollToCurrentMonth(using reader: ScrollViewProxy, animated: Bool) {
    let target = MonthIdentifier(month: viewModel.currentMonth, year: viewModel.currentYear)
    if animated {
      withAnimation {
        reader.scrollTo(target, anchor: .top)
      }
    } else {
      reader.scrollTo(target, anchor: .top)
    }
    hasScrolledToCurrentMonth = true
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
