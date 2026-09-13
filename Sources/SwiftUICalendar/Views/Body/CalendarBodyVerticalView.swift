import OSLog
import SwiftCommons
import SwiftUI

struct CalendarBodyVerticalView: View {
  private static let supportedMonthRadius = 1_500

  @Environment(CalendarViewModel.self) private var viewModel
  @Environment(Theme.self) private var theme
  @Environment(Typography.self) private var typography
  @Environment(\.calendarMetrics) private var metrics

  private let logger = Logger.swiftUICalendar(for: CalendarBodyVerticalView.self)

  @State private var anchor: MonthIdentifier?
  @State private var scrollPosition: MonthIdentifier?
  // The settle coordinator is a reference type held in `@State` rather than a value: its
  // bookkeeping changes on every scroll position update, and a value in `@State` would invalidate
  // this body — and with it the whole month list — on each one.
  @State private var settle = ScrollSettleCoordinator()

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
      .onDisappear {
        settle.cancel()
      }
      .onChange(of: anchor) { _, target in
        guard let target else { return }
        logger.debug(
          "Scrolling to anchor \(target.year, privacy: .public)-\(target.month, privacy: .public)")
        withTransaction(Transaction(animation: nil)) {
          proxy.scrollTo(target, anchor: .top)
        }
      }
      .onScrollPhaseChange { _, newPhase in
        settle.recordPhase(newPhase)
        if newPhase == .idle {
          scheduleScrollSettlement()
        }
      }
      .onChange(of: viewModel.currentDate) { _, _ in
        synchronizeExternalNavigation()
      }
      .onChange(of: viewModel.calendarSignature) { _, signature in
        logger.info(
          "Calendar signature changed to \(signature, privacy: .public); resetting window"
        )
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
    logger.info(
      "Initializing vertical window at \(current.year, privacy: .public)-\(current.month, privacy: .public)"
    )
    anchor = current
    scrollPosition = current
  }

  /// Rebuilds the window when navigation arrives from outside the vertical scroll.
  private func synchronizeExternalNavigation() {
    let target = currentMonthIdentifier
    guard target != scrollPosition else { return }
    logger.info(
      "External navigation to \(target.year, privacy: .public)-\(target.month, privacy: .public); regenerating window"
    )
    // Regenerate around the target so external navigation starts from a clean, centered window.
    resetWindow()
  }

  /// Applies the final visible month after a user scroll settles. Updating the model only at the
  /// end of a gesture prevents intermediate positions from repeatedly changing the header.
  private func scheduleScrollSettlement() {
    settle.schedule { settleScrollPosition() }
  }

  private func settleScrollPosition() {
    guard let position = scrollPosition, position != currentMonthIdentifier else { return }
    guard viewModel.engine.start(of: position) != nil else { return }
    guard let date = viewModel.engine.navigationDate(in: position, preferredDay: 1) else {
      logger.error(
        "No navigable date in settled month \(position.year, privacy: .public)-\(position.month, privacy: .public)"
      )
      return
    }
    CalendarSignpost.scroll.measure("settleScrollPosition") {
      do {
        try viewModel.navigate(to: date)
        logger.debug(
          "Settled on \(position.year, privacy: .public)-\(position.month, privacy: .public)")
      } catch {
        logger.error(
          "Failed to navigate to settled month", error: error,
          context: "month=\(position.year)-\(position.month)")
      }
    }
  }

  private func resetWindow() {
    let target = currentMonthIdentifier
    anchor = target
    scrollPosition = target
  }
}

/// Coalesces scroll-driven model updates and brackets the gesture with a signpost interval.
///
/// Every month boundary the user crosses bumps `scrollPosition`, and applying each one to the model
/// immediately would mutate observable state several times per frame. Scheduling through a
/// generation counter collapses a burst into a single update, and keeping that counter in a
/// reference type means the bookkeeping itself never invalidates the enclosing view.
@MainActor
private final class ScrollSettleCoordinator {
  private let logger = Logger.swiftUICalendar(for: ScrollSettleCoordinator.self)
  private var generation = 0
  private var scrollInterval: OSSignpostIntervalState?

  /// Runs `work` on the next main-actor turn, superseding any settlement already scheduled.
  func schedule(_ work: @escaping @MainActor () -> Void) {
    generation += 1
    let scheduled = generation
    Task { @MainActor in
      await Task.yield()
      guard scheduled == generation else { return }
      work()
    }
  }

  /// Opens a signpost interval while the user is scrolling and closes it when the scroll settles,
  /// so a stall can be read directly against the gesture on the Instruments timeline.
  func recordPhase(_ phase: ScrollPhase) {
    if phase == .idle {
      CalendarSignpost.scroll.end("verticalScroll", scrollInterval)
      scrollInterval = nil
      logger.debug("Vertical scroll idle")
    } else if scrollInterval == nil {
      scrollInterval = CalendarSignpost.scroll.begin("verticalScroll")
      logger.debug("Vertical scroll began")
    }
  }

  /// Drops any pending settlement and closes an open scroll interval.
  func cancel() {
    generation += 1
    CalendarSignpost.scroll.end("verticalScroll", scrollInterval)
    scrollInterval = nil
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
