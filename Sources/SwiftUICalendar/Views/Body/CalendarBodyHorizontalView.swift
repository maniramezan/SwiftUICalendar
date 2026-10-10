import SwiftUI

#if os(macOS)
import AppKit
#endif

struct CalendarBodyHorizontalView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private let reduceMotionOverride: Bool?
    private let allowsPaging: Bool
    private let keyboard: CalendarKeyboardCursor?
    private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }
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
    @State private var pagingGuard = CalendarPagingGuard()
    @State private var deferredContainerWidth: CGFloat?

    #if os(macOS)
    @State private var scrollMonitor: HorizontalScrollWheelMonitor?
    #endif

    private var layoutWidth: CGFloat {
        metrics.layoutWidth(containerWidth: containerWidth)
    }

    private var peekWidth: CGFloat {
        metrics.peekWidth(containerWidth: containerWidth)
    }

    private var pageWidth: CGFloat {
        metrics.pageWidth(containerWidth: containerWidth)
    }

    private var cellSize: CGFloat {
        gridLayout.cellSize
    }

    private var weekdayHeaderHeight: CGFloat {
        metrics.weekdayHeaderHeight(cellSize: cellSize)
    }

    private var columns: [GridItem] {
        gridLayout.columns
    }

    private var gridWidth: CGFloat {
        gridLayout.gridWidth
    }

    private var gridLayout: CalendarGridLayout {
        CalendarGridLayout(
            containerWidth: pageWidth,
            metrics: metrics,
            sizing: configuration.gridSizing
        )
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

    init(
        viewModel: CalendarViewModel, reduceMotion: Bool? = nil, allowsPaging: Bool = true,
        keyboard: CalendarKeyboardCursor? = nil
    ) {
        self.viewModel = viewModel
        self.reduceMotionOverride = reduceMotion
        self.allowsPaging = allowsPaging
        self.keyboard = keyboard
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
        layoutWidth: CGFloat,
        pager: CalendarMetrics.Pager
    ) -> Int? {
        let resolvedTranslation = HorizontalMonthSwipeResolver.resolvedTranslation(
            translation: translationWidth * layoutDirectionMultiplier,
            predictedEndTranslation: predictedEndTranslationWidth * layoutDirectionMultiplier,
            limit: layoutWidth,
            momentumWeight: pager.momentumWeight
        )
        return HorizontalMonthSwipeResolver.monthDelta(
            for: resolvedTranslation,
            threshold: pager.swipeThreshold(layoutWidth: layoutWidth)
        )
    }

    static func resetNavigationState() -> (offset: CGFloat, dragOffset: CGFloat, isNavigating: Bool)
    {
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

    static func nextOffset(
        currentOffset: CGFloat, width: CGFloat, layoutDirectionMultiplier: CGFloat
    )
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
                        .minimumScaleFactor(typography.resolvedMinScaleFactor)
                        .frame(height: weekdayHeaderHeight)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: gridWidth)
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
                    monthIdentifier: previousMonth,
                    showWeekdayHeader: false,
                    hideOverflowDays: true,
                    layoutWidth: pageWidth, keyboard: keyboard
                )
                // The model is required: this view receives it as a stored property, not from the
                // environment, so its pages would otherwise find none. Theme and typography are
                // already inherited.
                .environment(viewModel)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: pageWidth, alignment: .top)
                .background(heightReporter(for: .previous))
                .clipped()
                .offset(x: previousMonthBaseOffset + offset + dragOffset)
                .accessibilityHidden(true)

                // Current month (centered by default)
                CalendarBodyView(
                    monthIdentifier: currentMonth,
                    showWeekdayHeader: false,
                    hideOverflowDays: true,
                    layoutWidth: pageWidth, keyboard: keyboard
                )
                // The model is required: this view receives it as a stored property, not from the
                // environment, so its pages would otherwise find none. Theme and typography are
                // already inherited.
                .environment(viewModel)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: pageWidth, alignment: .top)
                .background(heightReporter(for: .current))
                .clipped()
                .offset(x: offset + dragOffset)

                // Next month — parked to the right.
                CalendarBodyView(
                    monthIdentifier: nextMonth,
                    showWeekdayHeader: false,
                    hideOverflowDays: true,
                    layoutWidth: pageWidth, keyboard: keyboard
                )
                // The model is required: this view receives it as a stored property, not from the
                // environment, so its pages would otherwise find none. Theme and typography are
                // already inherited.
                .environment(viewModel)
                .environment(\.layoutDirection, layoutDirection)
                .frame(width: pageWidth, alignment: .top)
                .background(heightReporter(for: .next))
                .clipped()
                .offset(x: nextMonthBaseOffset + offset + dragOffset)
                .accessibilityHidden(true)
            }
            .environment(\.layoutDirection, .leftToRight)
            // The carousel fills whatever width the parent proposes. Month pages are centered within
            // that space (via their individual `.frame(width: pageWidth)` + maxWidth centering).
            // Using `.frame(maxWidth: .infinity)` instead of a fixed `.frame(width: layoutWidth)`
            // prevents a stale `containerWidth` from producing an oversized frame during rotation.
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: max(calendarHeight, measuredHeight), alignment: .top)
            .clipped()
            .contentShape(Rectangle())
            .onPreferenceChange(HorizontalMonthHeightPreferenceKey.self) { heights in
                updateMeasuredHeight(heights.values.max() ?? 0)
            }
            // Let vertical gestures reach the enclosing row scroller. A swipe is recorded in the
            // paging guard so it cannot also select the day it started on.
            .environment(\.calendarPagingGuard, pagingGuard)
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard !isNavigating else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            // A drag that began horizontally and turned vertical belongs to the
                            // enclosing scroller; release the page it was dragging.
                            if dragOffset != 0 {
                                dragOffset = 0
                            }
                            return
                        }

                        pagingGuard.recordSwipe()
                        dragOffset = Self.nextDragOffset(
                            currentDragOffset: dragOffset,
                            translationWidth: value.translation.width,
                            limit: pageWidth,
                            isNavigating: isNavigating
                        )
                    }
                    .onEnded { value in
                        pagingGuard.endSwipe()
                        guard !isNavigating else { return }
                        guard abs(value.translation.width) > abs(value.translation.height) else {
                            // A diagonal drag may start horizontally and finish vertically.
                            // Clear any partial page offset when yielding to vertical scrolling.
                            dragOffset = 0
                            return
                        }

                        let monthDelta = Self.resolvedMonthDelta(
                            translationWidth: value.translation.width,
                            predictedEndTranslationWidth: value.predictedEndTranslation.width,
                            layoutDirectionMultiplier: layoutDirectionMultiplier,
                            layoutWidth: pageWidth,
                            pager: metrics.pager
                        )

                        switch Self.pagerAction(for: monthDelta) {
                        case .next:
                            goToNext(width: pageWidth)
                        case .previous:
                            goToPrevious(width: pageWidth)
                        case .snapBack:
                            withAnimation(
                                reduceMotion ? nil : metrics.pager.snapBackSpring.animation
                            ) {
                                dragOffset = 0
                            }
                        }
                    },
                including: allowsPaging ? .all : .subviews
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
            let current =
                viewModel.monthSnapshot(for: currentMonth)?.rowCount
                ?? CalendarGrid.maximumRowCount
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
            CalendarGrid.maximumRowCount
        }
    }

    private func height(forRowCount rowCount: Int) -> CGFloat {
        metrics.resolvedHeight(rowCount: rowCount, layoutWidth: pageWidth)
    }

    /// Swipe LEFT: next month slides in from the right.
    private func goToNext(width: CGFloat) {
        guard !isNavigating else {
            return
        }

        isNavigating = true
        withAnimation(
            reduceMotion ? nil : metrics.pager.pagingSpring.animation,
            completionCriteria: .logicallyComplete
        ) {
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
        withAnimation(
            reduceMotion ? nil : metrics.pager.pagingSpring.animation,
            completionCriteria: .logicallyComplete
        ) {
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

    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        let monitor = HorizontalScrollWheelMonitor(threshold: metrics.pager.scrollPageThreshold) {
            delta in
            guard Self.shouldHandleScrollPage(delta: delta, isNavigating: isNavigating) else {
                return
            }
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
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
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
    static func clampedTranslation(_ translation: CGFloat, limit: CGFloat) -> CGFloat {
        let clampedLimit = max(limit, 0)
        return min(max(translation, -clampedLimit), clampedLimit)
    }

    /// Blends a drag's current translation with its predicted end translation.
    ///
    /// - Parameter momentumWeight: How much of the prediction counts, from
    ///   `CalendarMetrics.Pager.momentumWeight`. `0` ignores the prediction entirely and a swipe
    ///   must be dragged all the way past the threshold; `1` commits on predicted intent alone.
    static func resolvedTranslation(
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        limit: CGFloat,
        momentumWeight: CGFloat
    ) -> CGFloat {
        let weight = min(max(momentumWeight, 0), 1)
        let weighted = (translation * (1 - weight)) + (predictedEndTranslation * weight)
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
