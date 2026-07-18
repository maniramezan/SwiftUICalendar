import SwiftUI

#if os(macOS)
  import AppKit
#endif

struct CalendarBodyHorizontalView: View {
  private static let headerHeightRatio: CGFloat = 0.45
  private static let minHeaderHeight: CGFloat = 24
  private static let heightCeilingPadding: CGFloat = 2
  private static let swipeThresholdRatio: CGFloat = 0.25
  private static let minimumSwipeThreshold: CGFloat = 56
  private static let peekContentFraction: CGFloat = 0.35
  private static let minimumPeekWidth: CGFloat = 12
  private static let maximumPeekWidth: CGFloat = 48
  private static let pagingAnimation = Animation.interactiveSpring(
    response: 0.32,
    dampingFraction: 0.88,
    blendDuration: 0.12
  )
  private static let snapBackAnimation = Animation.interactiveSpring(
    response: 0.24,
    dampingFraction: 0.9,
    blendDuration: 0.08
  )

  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.calendarConfiguration) private var configuration
  @Environment(\.calendarMetrics) private var metrics
  @Environment(\.layoutDirection) private var layoutDirection
  let viewModel: CalendarViewModel

  @State private var offset: CGFloat = 0
  @State private var dragOffset: CGFloat = 0
  @State private var containerWidth: CGFloat = 0
  @State private var measuredHeight: CGFloat = 0
  @State private var isNavigating = false
  @State private var deferredContainerWidth: CGFloat?

  #if os(macOS)
    @State private var scrollMonitor: HorizontalScrollWheelMonitor?
  #endif

  private var layoutWidth: CGFloat {
    Self.layoutWidth(containerWidth: containerWidth, minCalendarWidth: metrics.minCalendarWidth)
  }

  private var peekWidth: CGFloat {
    Self.peekWidth(
      containerWidth: layoutWidth,
      minCalendarWidth: metrics.minCalendarWidth,
      itemSpacing: metrics.itemSpacing,
      minCellSize: metrics.minCellSize,
      maxCellSize: metrics.maxCellSize
    )
  }

  private var pageWidth: CGFloat {
    Self.pageWidth(
      containerWidth: layoutWidth,
      minCalendarWidth: metrics.minCalendarWidth,
      itemSpacing: metrics.itemSpacing,
      minCellSize: metrics.minCellSize,
      maxCellSize: metrics.maxCellSize
    )
  }

  private var cellSize: CGFloat {
    Self.cellSize(
      layoutWidth: pageWidth,
      itemSpacing: metrics.itemSpacing,
      minCellSize: metrics.minCellSize,
      maxCellSize: metrics.maxCellSize
    )
  }

  private var weekdayHeaderHeight: CGFloat {
    Self.weekdayHeaderHeight(cellSize: cellSize)
  }

  private var columns: [GridItem] {
    CalendarGridLayout(containerWidth: pageWidth, metrics: metrics).columns
  }

  private var calendarHeight: CGFloat {
    height(forRowCount: rowCountForHeight)
  }

  /// `1` for LTR, `-1` for RTL.
  /// Applied manually because the ZStack is forced to `.leftToRight`
  /// to prevent SwiftUI's automatic coordinate flipping.
  private var layoutDirectionMultiplier: CGFloat {
    layoutDirection == .rightToLeft ? -1 : 1
  }

  private var previousMonthBaseOffset: CGFloat {
    Self.previousMonthBaseOffset(
      layoutWidth: pageWidth, layoutDirectionMultiplier: layoutDirectionMultiplier)
  }

  private var nextMonthBaseOffset: CGFloat {
    Self.nextMonthBaseOffset(
      layoutWidth: pageWidth, layoutDirectionMultiplier: layoutDirectionMultiplier)
  }

  private var currentMonth: MonthIdentifier {
    viewModel.visibleMonth
  }

  private var previousMonth: MonthIdentifier {
    viewModel.monthIdentifier(offset: -1) ?? currentMonth
  }

  private var nextMonth: MonthIdentifier {
    viewModel.monthIdentifier(offset: 1) ?? currentMonth
  }

  init(viewModel: CalendarViewModel) {
    self.viewModel = viewModel
  }

  static func layoutWidth(containerWidth: CGFloat, minCalendarWidth: CGFloat) -> CGFloat {
    max(containerWidth, minCalendarWidth)
  }

  /// Reserves space for a swipe affordance that reliably reveals real day content, not just
  /// empty margin. Day cells render as a `cellSize`-capped square *centered* within each grid
  /// column (see `CalendarBodyView`'s square-cell centering), so on wide layouts the column can
  /// be much wider than the visible cell — a peek narrower than that centering margin would only
  /// expose blank space. This reaches past the margin and into a meaningful fraction of the
  /// actual cell before falling back to whatever space remains above the minimum grid width.
  static func peekWidth(
    containerWidth: CGFloat,
    minCalendarWidth: CGFloat,
    itemSpacing: CGFloat,
    minCellSize: CGFloat,
    maxCellSize: CGFloat
  ) -> CGFloat {
    let approxCellSize = cellSize(
      layoutWidth: containerWidth,
      itemSpacing: itemSpacing,
      minCellSize: minCellSize,
      maxCellSize: maxCellSize
    )
    let approxColumnWidth = containerWidth / 7
    let marginToContent = max(0, (approxColumnWidth - approxCellSize) / 2)
    let desired = min(
      Self.maximumPeekWidth,
      max(Self.minimumPeekWidth, marginToContent + (approxCellSize * Self.peekContentFraction))
    )
    return min(desired, max(0, (containerWidth - minCalendarWidth) / 2))
  }

  /// The month page fits inside the viewport while retaining the configured minimum cell size.
  static func pageWidth(
    containerWidth: CGFloat,
    minCalendarWidth: CGFloat,
    itemSpacing: CGFloat,
    minCellSize: CGFloat,
    maxCellSize: CGFloat
  ) -> CGFloat {
    containerWidth
      - (2
        * peekWidth(
          containerWidth: containerWidth,
          minCalendarWidth: minCalendarWidth,
          itemSpacing: itemSpacing,
          minCellSize: minCellSize,
          maxCellSize: maxCellSize
        ))
  }

  static func cellSize(
    layoutWidth: CGFloat,
    itemSpacing: CGFloat,
    minCellSize: CGFloat,
    maxCellSize: CGFloat
  ) -> CGFloat {
    let totalInteritemSpacing = itemSpacing * 6
    let widthForCells = max(0, layoutWidth - totalInteritemSpacing)
    let columnWidth = widthForCells / 7
    return min(maxCellSize, max(minCellSize, columnWidth))
  }

  static func weekdayHeaderHeight(cellSize: CGFloat) -> CGFloat {
    max(Self.headerHeightRatio * cellSize, Self.minHeaderHeight)
  }

  static func previousMonthBaseOffset(layoutWidth: CGFloat, layoutDirectionMultiplier: CGFloat)
    -> CGFloat
  {
    -layoutWidth * layoutDirectionMultiplier
  }

  static func nextMonthBaseOffset(layoutWidth: CGFloat, layoutDirectionMultiplier: CGFloat)
    -> CGFloat
  {
    layoutWidth * layoutDirectionMultiplier
  }

  static func resolvedHeight(
    rowCount: Int,
    layoutWidth: CGFloat,
    itemSpacing: CGFloat,
    rowSpacing: CGFloat,
    minCellSize: CGFloat,
    maxCellSize: CGFloat
  ) -> CGFloat {
    let cs = cellSize(
      layoutWidth: layoutWidth,
      itemSpacing: itemSpacing,
      minCellSize: minCellSize,
      maxCellSize: maxCellSize
    )
    let totalRowSpacing = rowSpacing * CGFloat(rowCount - 1)
    let h = (CGFloat(rowCount) * cs) + totalRowSpacing
    return ceil(h) + Self.heightCeilingPadding
  }

  static func swipeThreshold(layoutWidth: CGFloat) -> CGFloat {
    max(layoutWidth * Self.swipeThresholdRatio, Self.minimumSwipeThreshold)
  }

  static func nextDragOffset(
    currentDragOffset: CGFloat,
    translationWidth: CGFloat,
    limit: CGFloat,
    isNavigating: Bool
  ) -> CGFloat {
    guard !isNavigating else { return currentDragOffset }
    return HorizontalMonthSwipeResolver.clampedTranslation(translationWidth, limit: limit)
  }

  static func resolvedMonthDelta(
    translationWidth: CGFloat,
    predictedEndTranslationWidth: CGFloat,
    layoutDirectionMultiplier: CGFloat,
    layoutWidth: CGFloat
  ) -> Int? {
    let resolvedTranslation = HorizontalMonthSwipeResolver.resolvedTranslation(
      translation: translationWidth * layoutDirectionMultiplier,
      predictedEndTranslation: predictedEndTranslationWidth * layoutDirectionMultiplier,
      limit: layoutWidth
    )
    return HorizontalMonthSwipeResolver.monthDelta(
      for: resolvedTranslation,
      threshold: swipeThreshold(layoutWidth: layoutWidth)
    )
  }

  static func resetNavigationState() -> (offset: CGFloat, dragOffset: CGFloat, isNavigating: Bool) {
    (0, 0, false)
  }

  static func pagerAction(for monthDelta: Int?) -> HorizontalPagerAction {
    switch monthDelta {
    case 1:
      .next
    case -1:
      .previous
    default:
      .snapBack
    }
  }

  static func nextOffset(currentOffset: CGFloat, width: CGFloat, layoutDirectionMultiplier: CGFloat)
    -> CGFloat
  {
    currentOffset + (-width * layoutDirectionMultiplier)
  }

  static func previousOffset(
    currentOffset: CGFloat, width: CGFloat, layoutDirectionMultiplier: CGFloat
  ) -> CGFloat {
    currentOffset + (width * layoutDirectionMultiplier)
  }

  static func shouldHandleScrollPage(delta: Int, isNavigating: Bool) -> Bool {
    guard !isNavigating else { return false }
    return delta == 1 || delta == -1
  }

  static func shouldDeferContainerWidthUpdate(isNavigating: Bool) -> Bool {
    isNavigating
  }

  var body: some View {
    VStack(spacing: metrics.rowSpacing) {
      // Static weekday header — does not scroll with the carousel
      LazyVGrid(columns: columns, alignment: .center, spacing: 0) {
        ForEach(Array(viewModel.headerTitles.enumerated()), id: \.offset) { _, day in
          Text(day)
            .font(typography.weekdayHeaderFont)
            .lineLimit(1)
            .minimumScaleFactor(typography.minScaleFactor ?? 1.0)
            .frame(height: weekdayHeaderHeight)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(width: pageWidth)
      .frame(maxWidth: .infinity)
      .accessibilityHidden(true)

      // Day-grid carousel.
      // Swipe semantics are fixed across locales:
      // swipe left to move forward (next month),
      // swipe right to move backward (previous month).
      //
      // Layout differs by direction:
      // LTR: previous | current | next
      // RTL: next | current | previous
      ZStack(alignment: .topLeading) {
        // Previous month — parked to the left.
        CalendarBodyView(
          displayMonth: previousMonth.month,
          displayYear: previousMonth.year,
          showWeekdayHeader: false,
          hideOverflowDays: true
        )
        .environment(viewModel)
        .environment(theme)
        .environment(typography)
        .environment(\.layoutDirection, layoutDirection)
        .frame(width: pageWidth, alignment: .top)
        .background(heightReporter(for: .previous))
        .clipped()
        .offset(x: previousMonthBaseOffset + offset + dragOffset)

        // Current month (centered by default)
        CalendarBodyView(
          displayMonth: currentMonth.month,
          displayYear: currentMonth.year,
          showWeekdayHeader: false,
          hideOverflowDays: true
        )
        .environment(viewModel)
        .environment(theme)
        .environment(typography)
        .environment(\.layoutDirection, layoutDirection)
        .frame(width: pageWidth, alignment: .top)
        .background(heightReporter(for: .current))
        .clipped()
        .offset(x: offset + dragOffset)

        // Next month — parked to the right.
        CalendarBodyView(
          displayMonth: nextMonth.month,
          displayYear: nextMonth.year,
          showWeekdayHeader: false,
          hideOverflowDays: true
        )
        .environment(viewModel)
        .environment(theme)
        .environment(typography)
        .environment(\.layoutDirection, layoutDirection)
        .frame(width: pageWidth, alignment: .top)
        .background(heightReporter(for: .next))
        .clipped()
        .offset(x: nextMonthBaseOffset + offset + dragOffset)
      }
      .environment(\.layoutDirection, .leftToRight)
      // Centering (rather than offsetting) the pageWidth-sized carousel within the wider
      // layoutWidth viewport reveals symmetric peek slivers of the parked months. An `.offset`
      // here does not reliably survive the outer `.frame`, since SwiftUI is free to resolve the
      // frame's alignment against the view's post-effect geometry.
      .frame(width: layoutWidth, alignment: .center)
      .frame(minHeight: max(calendarHeight, measuredHeight), alignment: .top)
      .clipped()
      .frame(maxWidth: .infinity, alignment: .top)
      .contentShape(Rectangle())
      .onPreferenceChange(HorizontalMonthHeightPreferenceKey.self) { heights in
        updateMeasuredHeight(heights.values.max() ?? 0)
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            guard !isNavigating else {
              return
            }

            dragOffset = Self.nextDragOffset(
              currentDragOffset: dragOffset,
              translationWidth: value.translation.width,
              limit: pageWidth,
              isNavigating: isNavigating
            )
          }
          .onEnded { value in
            guard !isNavigating else {
              return
            }

            let monthDelta = Self.resolvedMonthDelta(
              translationWidth: value.translation.width,
              predictedEndTranslationWidth: value.predictedEndTranslation.width,
              layoutDirectionMultiplier: layoutDirectionMultiplier,
              layoutWidth: pageWidth
            )

            switch Self.pagerAction(for: monthDelta) {
            case .next:
              goToNext(width: pageWidth)
            case .previous:
              goToPrevious(width: pageWidth)
            case .snapBack:
              withAnimation(Self.snapBackAnimation) {
                dragOffset = 0
              }
            }
          }
      )
      .onGeometryChange(for: CGFloat.self) { geometry in
        geometry.size.width
      } action: { width in
        updateContainerWidth(width)
      }
    }
    #if os(macOS)
      // Trackpad/scroll-wheel horizontal scrolling pages months on macOS, matching the iOS swipe.
      .onAppear { installScrollMonitor() }
      .onDisappear { removeScrollMonitor() }
    #endif
  }

  private func heightReporter(for position: HorizontalMonthPosition) -> some View {
    GeometryReader { geometry in
      Color.clear
        .preference(
          key: HorizontalMonthHeightPreferenceKey.self,
          value: [position: geometry.size.height]
        )
    }
  }

  private func updateContainerWidth(_ width: CGFloat) {
    if Self.shouldDeferContainerWidthUpdate(isNavigating: isNavigating) {
      // Track only the latest width; clear the deferral if the width returns to the applied
      // value so a stale intermediate size is never committed after the animation ends.
      deferredContainerWidth = width == containerWidth ? nil : width
      return
    }

    guard containerWidth != width else { return }
    withTransaction(Transaction(animation: nil)) {
      containerWidth = width
      offset = 0
      dragOffset = 0
    }
  }

  private func updateMeasuredHeight(_ height: CGFloat) {
    guard measuredHeight != height else { return }
    measuredHeight = height
  }

  private var rowCountForHeight: Int {
    switch configuration.horizontalHeightMode {
    case .hugContent:
      let current = viewModel.monthSnapshot(for: currentMonth)?.rowCount ?? 6
      let previous = viewModel.monthSnapshot(for: previousMonth)?.rowCount ?? current
      let next = viewModel.monthSnapshot(for: nextMonth)?.rowCount ?? current
      return Self.rowCount(
        mode: .hugContent, currentRows: current, previousRows: previous, nextRows: next)
    case .sixRows:
      return Self.rowCount(mode: .sixRows, currentRows: 0, previousRows: 0, nextRows: 0)
    }
  }

  /// Resolves the row count that drives the carousel height for a given height mode.
  /// `.hugContent` uses the tallest of the three parked months so paging never clips;
  /// `.sixRows` pins to a fixed six-row grid regardless of the months on screen.
  static func rowCount(
    mode: CalendarConfiguration.HorizontalHeightMode,
    currentRows: Int,
    previousRows: Int,
    nextRows: Int
  ) -> Int {
    switch mode {
    case .hugContent:
      max(currentRows, max(previousRows, nextRows))
    case .sixRows:
      6
    }
  }

  private func height(forRowCount rowCount: Int) -> CGFloat {
    Self.resolvedHeight(
      rowCount: rowCount,
      layoutWidth: pageWidth,
      itemSpacing: metrics.itemSpacing,
      rowSpacing: metrics.rowSpacing,
      minCellSize: metrics.minCellSize,
      maxCellSize: metrics.maxCellSize
    )
  }

  /// Swipe LEFT: next month slides in from the right.
  private func goToNext(width: CGFloat) {
    guard !isNavigating else {
      return
    }

    isNavigating = true
    withAnimation(Self.pagingAnimation, completionCriteria: .logicallyComplete) {
      // Move until the parked next month reaches center.
      offset = Self.nextOffset(
        currentOffset: offset,
        width: width,
        layoutDirectionMultiplier: layoutDirectionMultiplier
      )
      dragOffset = 0
    } completion: {
      finishNavigation(monthDelta: 1)
    }
  }

  /// Swipe RIGHT: previous month slides in from the left.
  private func goToPrevious(width: CGFloat) {
    guard !isNavigating else {
      return
    }

    isNavigating = true
    withAnimation(Self.pagingAnimation, completionCriteria: .logicallyComplete) {
      // Move until the parked previous month reaches center.
      offset = Self.previousOffset(
        currentOffset: offset,
        width: width,
        layoutDirectionMultiplier: layoutDirectionMultiplier
      )
      dragOffset = 0
    } completion: {
      finishNavigation(monthDelta: -1)
    }
  }

  private func finishNavigation(monthDelta: Int) {
    try? viewModel.updateMonth(byAdding: monthDelta)
    let reset = Self.resetNavigationState()
    withTransaction(Transaction(animation: nil)) {
      offset = reset.offset
      dragOffset = reset.dragOffset
    }
    isNavigating = reset.isNavigating
    if let deferredContainerWidth {
      withTransaction(Transaction(animation: nil)) {
        containerWidth = deferredContainerWidth
      }
      self.deferredContainerWidth = nil
    }
  }

  #if os(macOS)
    // MARK: - Trackpad / scroll-wheel paging (macOS)

    private static let scrollPageThreshold: CGFloat = 30

    private func installScrollMonitor() {
      guard scrollMonitor == nil else { return }
      let monitor = HorizontalScrollWheelMonitor(threshold: Self.scrollPageThreshold) { delta in
        guard Self.shouldHandleScrollPage(delta: delta, isNavigating: isNavigating) else { return }
        switch delta {
        case 1: goToNext(width: pageWidth)
        case -1: goToPrevious(width: pageWidth)
        default: break
        }
      }
      monitor.start()
      scrollMonitor = monitor
    }

    private func removeScrollMonitor() {
      scrollMonitor?.stop()
      scrollMonitor = nil
    }
  #endif
}

private enum HorizontalMonthPosition: Hashable {
  case previous
  case current
  case next
}

enum HorizontalPagerAction {
  case next
  case previous
  case snapBack
}

#if os(macOS)
  /// Owns a local scroll-wheel monitor and folds horizontal trackpad scrolls into month-page
  /// actions on macOS.
  ///
  /// The decision logic lives in `HorizontalScrollPagingResolver`; this type adds the AppKit
  /// plumbing. `fold(deltaX:deltaY:isMomentum:didBegin:didEnd:)` is separated from `NSEvent` so it
  /// can be unit tested without synthesizing events.
  @MainActor
  final class HorizontalScrollWheelMonitor {
    private var monitor: Any?
    private var accumulated: CGFloat = 0
    private let threshold: CGFloat
    private let onPage: (Int) -> Void

    init(threshold: CGFloat, onPage: @escaping (Int) -> Void) {
      self.threshold = threshold
      self.onPage = onPage
    }

    /// Begins observing scroll-wheel events. Events are delivered on the main thread.
    func start() {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
        MainActor.assumeIsolated {
          self?.fold(
            deltaX: event.scrollingDeltaX,
            deltaY: event.scrollingDeltaY,
            isMomentum: event.momentumPhase != [],
            didBegin: event.phase == .began,
            didEnd: event.phase == .ended || event.phase == .cancelled
          )
        }
        return event
      }
    }

    /// Stops observing scroll-wheel events.
    func stop() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }

    /// Folds one scroll sample into the running accumulator and emits a page delta
    /// (`1` next, `-1` previous) when the threshold is crossed.
    func fold(deltaX: CGFloat, deltaY: CGFloat, isMomentum: Bool, didBegin: Bool, didEnd: Bool) {
      let result = HorizontalScrollPagingResolver.resolve(
        accumulated: accumulated,
        deltaX: deltaX,
        deltaY: deltaY,
        isMomentum: isMomentum,
        didBegin: didBegin,
        didEnd: didEnd,
        threshold: threshold
      )
      accumulated = result.accumulated
      if let delta = result.pageDelta {
        onPage(delta)
      }
    }
  }
#endif

/// Pure decision logic for trackpad / scroll-wheel month paging on macOS.
///
/// Kept platform-independent (and free of `NSEvent`) so it can be unit tested. It mirrors the swipe
/// semantics: a leftward (negative) scroll past the threshold advances to the next month.
enum HorizontalScrollPagingResolver {
  /// Folds a scroll event into the running horizontal accumulator.
  ///
  /// - Returns: the new `accumulated` delta and a `pageDelta` of `1` (next), `-1` (previous), or
  ///   `nil` when the threshold has not been crossed.
  static func resolve(
    accumulated: CGFloat,
    deltaX: CGFloat,
    deltaY: CGFloat,
    isMomentum: Bool,
    didBegin: Bool,
    didEnd: Bool,
    threshold: CGFloat
  ) -> (accumulated: CGFloat, pageDelta: Int?) {
    // Ignore momentum so a single swipe pages predictably instead of running away.
    if isMomentum { return (accumulated, nil) }
    // Only act on predominantly-horizontal scrolls.
    guard abs(deltaX) > abs(deltaY), deltaX != 0 else { return (accumulated, nil) }

    var running = didBegin ? 0 : accumulated
    running += deltaX

    if running <= -threshold { return (0, 1) }
    if running >= threshold { return (0, -1) }
    if didEnd { return (0, nil) }
    return (running, nil)
  }
}

enum HorizontalMonthSwipeResolver {
  private static let momentumWeight: CGFloat = 0.65

  static func clampedTranslation(_ translation: CGFloat, limit: CGFloat) -> CGFloat {
    let clampedLimit = max(limit, 0)
    return min(max(translation, -clampedLimit), clampedLimit)
  }

  static func resolvedTranslation(
    translation: CGFloat,
    predictedEndTranslation: CGFloat,
    limit: CGFloat
  ) -> CGFloat {
    let weighted = (translation * (1 - momentumWeight)) + (predictedEndTranslation * momentumWeight)
    return clampedTranslation(weighted, limit: limit)
  }

  /// Returns the month delta for a swipe gesture.
  ///
  /// - Returns: `+1` (go to next), `-1` (go to previous),
  ///   `nil` if the translation is within threshold.
  ///
  /// This resolver intentionally keeps the same swipe mapping
  /// for both LTR and RTL:
  /// swipe left (negative) → next,
  /// swipe right (positive) → previous.
  static func monthDelta(
    for translation: CGFloat,
    threshold: CGFloat
  ) -> Int? {
    if translation < -threshold { return 1 }
    if translation > threshold { return -1 }
    return nil
  }
}

private struct HorizontalMonthHeightPreferenceKey: PreferenceKey {
  static let defaultValue: [HorizontalMonthPosition: CGFloat] = [:]

  static func reduce(
    value: inout [HorizontalMonthPosition: CGFloat],
    nextValue: () -> [HorizontalMonthPosition: CGFloat]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { max($0, $1) })
  }
}

#Preview {
  @Previewable @State var vm = CalendarViewModel.test(identifier: .persian)
  return CalendarBodyHorizontalView(viewModel: vm)
    .environment(Theme.default)
    .environment(Typography.default)
}
