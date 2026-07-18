import SwiftUI

struct CalendarBodyVerticalView: View {
  private static let initialRadius = 18
  private static let expansionCount = 18
  private static let expansionThreshold = 5

  @Environment(CalendarViewModel.self) private var viewModel
  @Environment(Theme.self) private var theme
  @Environment(Typography.self) private var typography
  @Environment(\.calendarMetrics) private var metrics

  // The anchor month must be the FIRST rendered item whenever the window is (re)generated —
  // writing `.scrollPosition(id:)` to jump to a non-zero index of a freshly laid-out
  // `LazyVStack` is unreliable in current SDKs (the list can rest at the array's start
  // instead, observed on the macos-15 CI runner). The window therefore starts at the anchor
  // (`lowerOffset == 0`) and expands backward one runloop tick later (`.task(id: anchor)`),
  // once the scroll view is settled on the anchor: prepending items while the position binding
  // already holds the visible month uses scroll-position identity anchoring, not a positional
  // jump, so the visible month stays put and earlier months become reachable by scrolling up.
  @State private var anchor: MonthIdentifier?
  @State private var lowerOffset = 0
  @State private var upperOffset = Self.initialRadius
  @State private var scrollPosition: MonthIdentifier?
  // Bumped whenever the window is regenerated so the deferred backward expansion re-runs even
  // when the new anchor equals the previous one (e.g. "today" navigation back to the anchor).
  @State private var windowGeneration = 0

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
    .task(id: windowGeneration) {
      expandBackwardFromAnchor()
    }
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
    windowGeneration += 1
  }

  private func synchronizeExternalNavigation() {
    let target = currentMonthIdentifier
    guard target != scrollPosition else { return }
    // Regenerate the window with the target first — see the state declarations for why the
    // anchor must start the window instead of being scrolled to.
    anchor = target
    lowerOffset = 0
    upperOffset = Self.initialRadius
    scrollPosition = target
    windowGeneration += 1
  }

  /// Expands the window backward once the freshly generated window has settled on its anchor,
  /// making months before the anchor reachable without a positional scroll jump.
  private func expandBackwardFromAnchor() {
    guard anchor != nil, lowerOffset == 0 else { return }
    withTransaction(Transaction(animation: nil)) {
      lowerOffset = -Self.initialRadius
    }
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
