import SwiftCommons
import SwiftUI

struct CalendarBodyVerticalView: View {
  @Environment(CalendarViewModel.self) var viewModel
  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.calendarMetrics) private var metrics
  @State private var scrollPosition: MonthIdentifier?
  // The vertical scroll must not materialize the full supported year range up front (default
  // 1900...2100 = 2400 months, each a full day grid) — `LazyVStack` still needs an identity/attribute
  // graph node per `ForEach` item even for off-screen rows, and a list that large can exhaust
  // AttributeGraph's node table and crash.
  //
  // The loaded window is anchored so the *first* rendered month is always whichever month the
  // scroll view should currently rest on: `.scrollPosition(id:anchor:)`, when written to jump to
  // an id deep within a large `LazyVStack`, was observed to render the target month correctly in
  // the first visible row, but every row *after* it incorrectly fell back to rendering from the
  // start of the array (e.g. jumping to July 2026 within a 2016...2036 window would show July
  // 2026 followed immediately by January 2016, not August 2026) — reproducible with a trivial
  // placeholder in place of `CalendarBodyView`, with/without `ScrollViewReader`, at any window
  // size or jump distance, so long as the target wasn't already the array's first element. That
  // looks like a genuine `LazyVStack` + `.scrollPosition(id:)` bug in this SDK for jumps to a
  // non-zero index, not something fixable by this view's own state management.
  //
  // The workaround: never ask the scroll view to jump to a non-zero index. Instead, whenever the
  // target month changes (Today button, month/year picker, initial load), the window is
  // regenerated to *start* at that month — the scroll view's natural resting position (top of a
  // freshly laid-out list) already matches the target, so no jump is ever needed. The trade-off:
  // this only supports scrolling *forward* from wherever the window last started, not backward
  // into months before it — deliberately navigating to an earlier month (rather than organically
  // scrolling there) is still fully supported, since that just restarts the window there instead.
  @State private var startMonthIdentifier: MonthIdentifier?

  private static let forwardMonths = 240

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
      resetWindowIfNeeded()
    }
    .onChange(of: viewModel.currentDate) { _, _ in
      let target = currentMonthIdentifier
      guard startMonthIdentifier != target else { return }
      // Regenerating the window (rather than writing `scrollPosition`) so the target is the
      // array's first element — see the type-level comment for why this avoids the scroll bug.
      startMonthIdentifier = target
      scrollPosition = target
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
    guard let start = startMonthIdentifier else { return [] }
    return Self.generateMonthItems(
      start: start,
      count: Self.forwardMonths,
      maxYear: viewModel.maxYear,
      metadata: { month, year in viewModel.monthMetadata(month: month, year: year) },
      nextMetadata: { month, year in
        viewModel.monthMetadata(month: month, year: year, offset: 1)
      },
      monthTitle: { month, year in viewModel.monthSymbol(for: month, year: year) }
    )
  }

  /// Generates up to `count` sequential months starting at `start`, stopping early if a month's
  /// metadata can't be resolved or once `maxYear` has been reached. Extracted as a pure, testable
  /// function: `metadata`/`nextMetadata` let tests substitute a fake calendar sequence instead of
  /// depending on a full `CalendarViewModel`.
  static func generateMonthItems(
    start: MonthIdentifier,
    count: Int,
    maxYear: Int,
    metadata: (Int, Int) -> CalendarViewModel.MonthMetadata?,
    nextMetadata: (Int, Int) -> CalendarViewModel.MonthMetadata?,
    monthTitle: (Int, Int) -> String
  ) -> [VerticalMonthItem] {
    var items: [VerticalMonthItem] = []
    var current = start

    for _ in 0..<count {
      guard let currentMetadata = metadata(current.month, current.year) else { break }
      let id = MonthIdentifier(month: currentMetadata.month, year: currentMetadata.year)
      items.append(
        VerticalMonthItem(
          id: id,
          month: currentMetadata.month,
          year: currentMetadata.year,
          monthTitle: monthTitle(currentMetadata.month, currentMetadata.year)
        )
      )

      guard let next = nextMetadata(current.month, current.year), next.year <= maxYear else {
        break
      }
      current = MonthIdentifier(month: next.month, year: next.year)
    }
    return items
  }

  private var currentMonthIdentifier: MonthIdentifier {
    MonthIdentifier(month: viewModel.currentMonth, year: viewModel.currentYear)
  }

  /// Seeds the initial window starting at the current month, if not already set.
  private func resetWindowIfNeeded() {
    guard startMonthIdentifier == nil else { return }
    startMonthIdentifier = currentMonthIdentifier
    scrollPosition = currentMonthIdentifier
  }
}

#Preview {
  CalendarBodyVerticalView()
    .environment(CalendarViewModel.test(identifier: .persian, selection: .range(Date(), nil)))
    .environment(Theme.default)
    .environment(Typography.default)
}

struct MonthIdentifier: Hashable {
  let month: Int
  let year: Int
}

struct VerticalMonthItem: Identifiable {
  let id: MonthIdentifier
  let month: Int
  let year: Int
  let monthTitle: String
}
