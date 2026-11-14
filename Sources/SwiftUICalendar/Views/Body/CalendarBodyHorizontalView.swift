import OSLog
import SwiftCommons
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
    @State private var navigationGeneration = 0
    private let logger = Logger.swiftUICalendar(for: Self.self)

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
            // Layout differs by direction:
            // LTR: previous | current | next
            // RTL: next | current | previous
            ZStack(alignment: .topLeading) {
                ForEach(pages) { page in
                    CalendarBodyView(
                        monthIdentifier: page.id,
                        showWeekdayHeader: false,
                        hideOverflowDays: true,
                        layoutWidth: pageWidth, keyboard: keyboard
                    )
                    .environment(viewModel)
                    .environment(\.layoutDirection, layoutDirection)
                    .frame(width: pageWidth, alignment: .top)
                    .background(heightReporter(for: page.id))
                    .clipped()
                    .offset(
                        x: CGFloat(page.offset) * pageWidth * layoutDirectionMultiplier
                            + offset + dragOffset
                    )
                    .accessibilityHidden(page.offset != 0)
                    .allowsHitTesting(page.offset == 0)
                }
            }
            .animation(
                reduceMotion ? nil : metrics.pager.pagingSpring.animation,
                value: currentMonth
            )
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
            // Let vertical gestures reach the enclosing row scroller (see `HorizontalPagingGesture`).
            // A swipe is recorded in the paging guard so it cannot also select the day it started on.
            .environment(\.calendarPagingGuard, pagingGuard)
            .modifier(
                HorizontalPagingGesture(
                    isEnabled: allowsPaging, onChanged: dragChanged, onEnded: dragEnded)
            )
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                updateContainerWidth(width)
            }
        }
        .onChange(of: currentMonth) { _, _ in
            guard isNavigating else { return }
            navigationGeneration += 1
            resetNavigation()
        }
        .onDisappear {
            navigationGeneration += 1
            resetNavigation()
        }
        #if os(macOS)
        .background {
            HorizontalScrollWheelRegion(
                threshold: metrics.pager.scrollPageThreshold, isEnabled: allowsPaging
            ) { delta in
                guard Self.shouldHandleScrollPage(delta: delta, isNavigating: isNavigating) else {
                    return
                }
                let directedDelta = delta * Int(layoutDirectionMultiplier)
                if directedDelta == 1 {
                    goToNext(width: pageWidth)
                } else {
                    goToPrevious(width: pageWidth)
                }
            }
        }
        #endif
    }

    private func dragChanged(_ translation: CGSize) {
        guard !isNavigating else { return }
        guard abs(translation.width) > abs(translation.height) else {
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
            translationWidth: translation.width,
            limit: pageWidth,
            isNavigating: isNavigating
        )
    }

    private func dragEnded(_ translation: CGSize, predictedEndTranslation: CGSize) {
        pagingGuard.endSwipe()
        guard !isNavigating else { return }
        guard abs(translation.width) > abs(translation.height) else {
            // A diagonal drag may start horizontally and finish vertically.
            // Clear any partial page offset when yielding to vertical scrolling.
            dragOffset = 0
            return
        }

        let monthDelta = Self.resolvedMonthDelta(
            translationWidth: translation.width,
            predictedEndTranslationWidth: predictedEndTranslation.width,
            layoutDirectionMultiplier: layoutDirectionMultiplier,
            layoutWidth: pageWidth,
            pager: metrics.pager
        )
        logger.debug("Horizontal swipe ended with month delta \(monthDelta ?? 0, privacy: .public)")

        switch Self.pagerAction(for: monthDelta) {
        case .next:
            goToNext(width: pageWidth)
        case .previous:
            goToPrevious(width: pageWidth)
        case .snapBack:
            withAnimation(reduceMotion ? nil : metrics.pager.snapBackSpring.animation) {
                dragOffset = 0
            }
        }
    }

    private func heightReporter(for month: MonthIdentifier) -> some View {
        GeometryReader { geometry in
            Color.clear
                .preference(
                    key: HorizontalMonthHeightPreferenceKey.self,
                    value: [month: geometry.size.height]
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

    private var pages: [HorizontalMonthPage] {
        Self.pages(viewModel: viewModel)
    }

    static func pages(viewModel: CalendarViewModel) -> [HorizontalMonthPage] {
        [-1, 0, 1].compactMap { offset in
            viewModel.monthIdentifier(offset: offset).map {
                HorizontalMonthPage(id: $0, offset: offset)
            }
        }
    }

    private func goToNext(width: CGFloat) {
        navigate(by: 1, width: width)
    }

    private func goToPrevious(width: CGFloat) {
        navigate(by: -1, width: width)
    }

    private func navigate(by monthDelta: Int, width: CGFloat) {
        guard !isNavigating, viewModel.monthIdentifier(offset: monthDelta) != nil else {
            withAnimation(reduceMotion ? nil : metrics.pager.snapBackSpring.animation) {
                dragOffset = 0
            }
            return
        }
        isNavigating = true
        navigationGeneration += 1
        let generation = navigationGeneration
        withAnimation(
            reduceMotion ? nil : metrics.pager.pagingSpring.animation,
            completionCriteria: .removed
        ) {
            offset = -CGFloat(monthDelta) * width * layoutDirectionMultiplier
            dragOffset = 0
        } completion: {
            guard generation == navigationGeneration else { return }
            finishNavigation(monthDelta: monthDelta)
        }
    }

    private func finishNavigation(monthDelta: Int) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isNavigating = false
            do {
                try viewModel.updateMonth(byAdding: monthDelta)
            } catch {
                logger.error(
                    "Failed to finish horizontal paging", error: error,
                    context: "month delta \(monthDelta)")
            }
            resetNavigation()
        }
    }

    private func resetNavigation() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let reset = Self.resetNavigationState()
            offset = reset.offset
            dragOffset = reset.dragOffset
            isNavigating = reset.isNavigating
            if let deferredContainerWidth {
                containerWidth = deferredContainerWidth
                self.deferredContainerWidth = nil
            }
        }
    }

}

struct HorizontalMonthPage: Identifiable {
    let id: MonthIdentifier
    let offset: Int
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
    var threshold: CGFloat
    var isEnabled = true {
        didSet { if !isEnabled { accumulated = 0 } }
    }
    var onPage: (Int) -> Void
    private weak var region: NSView?

    init(threshold: CGFloat, onPage: @escaping (Int) -> Void) {
        self.threshold = threshold
        self.onPage = onPage
    }

    /// Begins observing scroll-wheel events. Events are delivered on the main thread.
    func start(in region: NSView) {
        self.region = region
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            MainActor.assumeIsolated {
                guard let self,
                    self.contains(window: event.window, location: event.locationInWindow)
                else {
                    self?.accumulated = 0
                    return
                }
                self.fold(
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

    func contains(window: NSWindow?, location: CGPoint) -> Bool {
        guard isEnabled, let region, let window, region.window === window,
            !region.isHiddenOrHasHiddenAncestor
        else { return false }
        return region.bounds.intersection(region.visibleRect).contains(
            region.convert(location, from: nil))
    }

    /// Stops observing scroll-wheel events.
    func stop() {
        accumulated = 0
        region = nil
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    /// Folds one scroll sample into the running accumulator and emits a page delta
    /// (`1` next, `-1` previous) when the threshold is crossed.
    func fold(deltaX: CGFloat, deltaY: CGFloat, isMomentum: Bool, didBegin: Bool, didEnd: Bool) {
        guard isEnabled else { return }
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
        let initial = didBegin ? 0 : accumulated
        if isMomentum { return (didEnd ? 0 : initial, nil) }
        guard abs(deltaX) > abs(deltaY), deltaX != 0 else {
            return (didEnd ? 0 : initial, nil)
        }

        let running = initial + deltaX

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
    static let defaultValue: [MonthIdentifier: CGFloat] = [:]

    static func reduce(
        value: inout [MonthIdentifier: CGFloat],
        nextValue: () -> [MonthIdentifier: CGFloat]
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
