import SwiftUI

struct CalendarBodyVerticalView: View {
  private static let initialRadius = 18
  private static let expansionCount = 18
  private static let expansionThreshold = 5

  @Environment(CalendarViewModel.self) private var viewModel
  @Environment(Theme.self) private var theme
  @Environment(Typography.self) private var typography
  @Environment(\.calendarMetrics) private var metrics

  @State private var anchor: MonthIdentifier?
  @State private var lowerOffset = -Self.initialRadius
  @State private var upperOffset = Self.initialRadius
  @State private var scrollPosition: MonthIdentifier?

  private var monthItems: [VerticalMonthItem] {
    guard let anchor else { return [] }
    return Self.generateMonthItems(
      anchor: anchor,
      lowerOffset: lowerOffset,
      upperOffset: upperOffset,
      resolve: { offset in viewModel.monthIdentifier(offset: offset, from: anchor) },
      title: { identifier in
        viewModel.monthSymbol(for: identifier.month, year: identifier.year)
      }
    )
  }

  var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      LazyVStack(spacing: metrics.monthSpacing) {
        ForEach(monthItems) { item in
          VerticalMonthView(item: item)
            .environment(viewModel)
            .environment(theme)
            .environment(typography)
            .id(item.id)
        }
      }
      .scrollTargetLayout()
      .padding(.vertical, metrics.itemSpacing)
      .padding(.horizontal)
    }
    .scrollPosition(id: $scrollPosition, anchor: .top)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .onAppear(perform: initializeWindow)
    .onChange(of: viewModel.currentDate) { _, _ in
      synchronizeExternalNavigation()
    }
    .onChange(of: scrollPosition) { _, position in
      guard let position else { return }
      expandWindowIfNeeded(around: position)
      guard
        position != currentMonthIdentifier,
        let date = viewModel.firstDate(month: position.month, year: position.year)
      else { return }
      try? viewModel.navigate(to: date)
    }
  }

  static func generateMonthItems(
    anchor: MonthIdentifier,
    lowerOffset: Int,
    upperOffset: Int,
    resolve: (Int) -> MonthIdentifier?,
    title: (MonthIdentifier) -> String
  ) -> [VerticalMonthItem] {
    guard lowerOffset <= upperOffset else { return [] }
    return (lowerOffset...upperOffset).compactMap { offset in
      guard let identifier = resolve(offset) else { return nil }
      return VerticalMonthItem(id: identifier, monthTitle: title(identifier))
    }
  }

  static func expandedOffsets(
    lowerOffset: Int,
    upperOffset: Int,
    visibleIndex: Int,
    itemCount: Int,
    threshold: Int,
    expansionCount: Int
  ) -> (lower: Int, upper: Int) {
    var lower = lowerOffset
    var upper = upperOffset
    if visibleIndex <= threshold {
      lower -= expansionCount
    }
    if visibleIndex >= max(0, itemCount - threshold - 1) {
      upper += expansionCount
    }
    return (lower, upper)
  }

  private var currentMonthIdentifier: MonthIdentifier {
    viewModel.visibleMonth
  }

  private func initializeWindow() {
    guard anchor == nil else { return }
    let current = currentMonthIdentifier
    anchor = current
    scrollPosition = current
  }

  private func synchronizeExternalNavigation() {
    let target = currentMonthIdentifier
    guard target != scrollPosition else { return }
    anchor = target
    lowerOffset = -Self.initialRadius
    upperOffset = Self.initialRadius
    scrollPosition = target
  }

  private func expandWindowIfNeeded(around position: MonthIdentifier) {
    let items = monthItems
    guard let index = items.firstIndex(where: { $0.id == position }) else { return }
    let expanded = Self.expandedOffsets(
      lowerOffset: lowerOffset,
      upperOffset: upperOffset,
      visibleIndex: index,
      itemCount: items.count,
      threshold: Self.expansionThreshold,
      expansionCount: Self.expansionCount
    )
    guard expanded.lower != lowerOffset || expanded.upper != upperOffset else { return }
    withTransaction(Transaction(animation: nil)) {
      lowerOffset = expanded.lower
      upperOffset = expanded.upper
      scrollPosition = position
    }
  }
}

private struct VerticalMonthView: View {
  @Environment(CalendarViewModel.self) private var viewModel
  @Environment(Theme.self) private var theme
  @Environment(Typography.self) private var typography
  @Environment(\.calendarMetrics) private var metrics

  let item: VerticalMonthItem

  var body: some View {
    VStack(spacing: metrics.itemSpacing) {
      HStack {
        Text(item.monthTitle)
          .font(typography.monthHeaderFont)
        Text(NumberFormatter.formatYear(item.id.year, locale: viewModel.locale))
          .font(typography.monthHeaderFont)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      CalendarBodyView(
        displayMonth: item.id.month,
        displayYear: item.id.year,
        hideOverflowDays: true,
        navigatesOnOverflowTap: false
      )
      .environment(theme)
      .environment(typography)
    }
  }
}

struct VerticalMonthItem: Identifiable, Equatable {
  let id: MonthIdentifier
  let monthTitle: String
}

#Preview {
  CalendarBodyVerticalView()
    .environment(CalendarViewModel.test(identifier: .persian, selection: .range(Date(), nil)))
    .environment(Theme.default)
    .environment(Typography.default)
}
