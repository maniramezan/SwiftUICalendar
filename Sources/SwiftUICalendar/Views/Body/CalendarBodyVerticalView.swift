import SwiftUI

struct CalendarBodyVerticalView: View {
  private static let supportedMonthRadius = 1_500

  @Environment(CalendarViewModel.self) private var viewModel
  @Environment(Theme.self) private var theme
  @Environment(Typography.self) private var typography
  @Environment(\.calendarMetrics) private var metrics

  @State private var anchor: MonthIdentifier?
  @State private var scrollPosition: MonthIdentifier?
  @State private var settleGeneration = 0

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical, showsIndicators: true) {
        LazyVStack(spacing: metrics.monthSpacing) {
          if let anchor {
            ForEach(-Self.supportedMonthRadius...Self.supportedMonthRadius, id: \.self) { offset in
              if let identifier = viewModel.monthIdentifier(offset: offset, from: anchor) {
                VerticalMonthView(
                  item: VerticalMonthItem(
                    id: identifier,
                    monthTitle: viewModel.monthSymbol(for: identifier)
                  )
                )
                .environment(viewModel)
                .environment(theme)
                .environment(typography)
                .id(identifier)
              }
            }
          }
        }
        .scrollTargetLayout()
        .padding(.vertical, metrics.itemSpacing)
        .padding(.horizontal)
      }
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $scrollPosition, anchor: .top)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .onAppear {
        initializeWindow()
      }
      .onChange(of: anchor) { _, target in
        guard let target else { return }
        withTransaction(Transaction(animation: nil)) {
          proxy.scrollTo(target, anchor: .top)
        }
      }
      .onScrollPhaseChange { _, newPhase in
        if newPhase == .idle {
          scheduleScrollSettlement()
        }
      }
      .onChange(of: viewModel.currentDate) { _, _ in
        synchronizeExternalNavigation()
      }
      .onChange(of: viewModel.calendarSignature) { _, _ in
        resetWindow()
      }
      .onChange(of: scrollPosition) { _, position in
        guard let position else { return }
        guard position != currentMonthIdentifier else { return }
        guard viewModel.engine.start(of: position) != nil else { return }
        scheduleScrollSettlement()
      }
    }
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

  /// Rebuilds the window when navigation arrives from outside the vertical scroll.
  private func synchronizeExternalNavigation() {
    let target = currentMonthIdentifier
    guard target != scrollPosition else { return }
    // Regenerate around the target so external navigation starts from a clean, centered window.
    resetWindow()
  }

  /// Applies the final visible month after a user scroll settles. Updating the model only at the
  /// end of a gesture prevents intermediate positions from repeatedly changing the header.
  private func scheduleScrollSettlement() {
    settleGeneration += 1
    let generation = settleGeneration
    Task { @MainActor in
      await Task.yield()
      guard generation == settleGeneration else { return }
      settleScrollPosition()
    }
  }

  private func settleScrollPosition() {
    guard let position = scrollPosition, position != currentMonthIdentifier else { return }
    guard viewModel.engine.start(of: position) != nil else { return }
    guard let date = viewModel.engine.navigationDate(in: position, preferredDay: 1) else { return }
    try? viewModel.navigate(to: date)
  }

  private func resetWindow() {
    let target = currentMonthIdentifier
    anchor = target
    scrollPosition = target
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
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier(
        "vertical-month-header-\(item.id.year)-\(item.id.month)"
      )

      CalendarBodyView(
        monthIdentifier: item.id,
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
