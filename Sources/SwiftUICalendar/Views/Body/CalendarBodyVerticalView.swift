import OSLog
import SwiftCommons
import SwiftUI
import SwiftUICalendarAccessibility

struct CalendarBodyVerticalView: View {
    var keyboard: CalendarKeyboardCursor? = nil
    @Environment(CalendarViewModel.self) private var viewModel
    @Environment(Typography.self) private var typography
    @Environment(\.calendarMetrics) private var metrics

    private let logger = Logger.swiftUICalendar(for: CalendarBodyVerticalView.self)

    @State private var anchor: MonthIdentifier?
    @State private var requestedAnchor: MonthIdentifier?
    @State private var navigationRevision = 0
    @State private var months: [MonthIdentifier] = []
    @State private var scrollPosition: MonthIdentifier?
    @State private var realizedMonths: Set<MonthIdentifier> = []
    @State private var navigationPosition = ScrollPosition(idType: MonthIdentifier.self)
    @State private var pendingDayReveal: Date?
    // The settle coordinator is a reference type held in `@State` rather than a value: its
    // bookkeeping changes on every scroll position update, and a value in `@State` would invalidate
    // this body — and with it the whole month list — on each one.
    @State private var settle = ScrollSettleCoordinator()
    // Same reasoning as `settle`: prefetch bookkeeping (in-flight task, last known position) must
    // not invalidate this body on every scroll tick.
    @State private var prefetch = MonthPrefetchCoordinator()
    // Measured once for the whole list and handed to every row as `layoutWidth`. Without it each
    // newly realized month measured itself via `.onGeometryChange` and wrote its own `@State`,
    // costing a second body/layout pass per row during a fast scroll. Changes only on resize.
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        ScrollViewReader { proxy in
            // See `CalendarScrollChrome.showsIndicators` for why macOS hides the indicator.
            ScrollView(.vertical, showsIndicators: CalendarScrollChrome.showsIndicators) {
                LazyVStack(spacing: metrics.monthSpacing) {
                    // Month identity must survive re-anchoring. Relative offsets refer to a
                    // different month after navigation and invalidate lazy placement caches.
                    ForEach(months, id: \.self) { identifier in
                        // No `.environment(...)` re-injection here: the model, theme, and
                        // typography are already inherited from `CalendarView`. Each
                        // observable `.environment(_:)` call (and each
                        // `@Environment(Type.self)` a row declares) instantiates a generic
                        // key path at runtime; per realized row, that was the dominant cost
                        // of a fast-scroll frame.
                        VerticalMonthView(
                            item: VerticalMonthItem(
                                id: identifier,
                                monthTitle: viewModel.monthSymbol(for: identifier)
                            ),
                            locale: viewModel.locale,
                            typography: typography,
                            // `nil` until the first measurement: rows then measure
                            // themselves, exactly as before.
                            layoutWidth: contentWidth > 0 ? contentWidth : nil,
                            keyboard: keyboard
                        )
                        .onAppear { realizedMonths.insert(identifier) }
                        .onDisappear { realizedMonths.remove(identifier) }
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity)
                // Measured inside the horizontal padding, so it equals the width each row's grid
                // would otherwise have measured for itself.
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.width
                } action: { width in
                    guard width != contentWidth else { return }
                    logger.debug("Vertical content width changed to \(width, privacy: .public)")
                    contentWidth = width
                }
                .padding(.vertical, metrics.itemSpacing)
                .padding(.horizontal, metrics.monthInset)
            }
            .scrollTargetBehavior(
                CalendarVerticalScrollTargetBehavior(alignsMonths: requestedAnchor == nil)
            )
            .calendarVerticalScrollPosition(navigation: $navigationPosition, month: $scrollPosition)
            .onScrollTargetVisibilityChange(
                idType: MonthIdentifier.self, threshold: VerticalMonthWindow.visibilityThreshold
            ) { visible in
                #if !os(macOS)
                let visible = Set(visible)
                scrollPosition = months.first(where: visible.contains)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                initializeWindow()
            }
            .task(id: requestedAnchor) {
                guard let target = requestedAnchor else { return }
                #if !os(macOS)
                await Task.yield()
                guard !Task.isCancelled else { return }
                #endif
                // Resolve the ID after the replacement window has entered the view tree. Issuing
                // ScrollPosition.scrollTo in the same transaction as replacing the lazy rows can
                // leave UIKit's placement estimates on the preceding month in a narrow viewport.
                withTransaction(Transaction(animation: nil)) {
                    #if os(macOS)
                    proxy.scrollTo(target, anchor: .top)
                    #else
                    navigationPosition.scrollTo(id: target, anchor: .top)
                    #endif
                }
            }
            .onChange(of: contentWidth) { _, _ in
                initializeWindow()
            }
            .onDisappear {
                settle.cancel()
                prefetch.cancel()
                viewModel.previewScrolledMonth(nil)
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase == .tracking || newPhase == .interacting {
                    pendingDayReveal = nil
                    requestedAnchor = nil
                }
                settle.recordPhase(newPhase)
                if newPhase == .idle {
                    scheduleScrollSettlement()
                }
            }
            // `scrollRequest`, not `date`: a settled scroll here navigates the model, which moves
            // the cursor to follow, so keying off the cursor's date would make this list scroll
            // itself in response to the user's own fling.
            .onChange(of: keyboard?.scrollRequest) { _, request in
                guard keyboard?.isActive == true, let request else { return }
                proxy.scrollTo(request.identity)
            }
            .onChange(of: viewModel.currentDate) { _, _ in
                synchronizeExternalNavigation(proxy: proxy)
            }
            .onChange(of: viewModel.todayScrollRequest) { _, _ in
                synchronizeExternalNavigation(proxy: proxy, isTodayRequest: true)
            }
            .onChange(of: viewModel.calendarSignature) { _, signature in
                logger.info(
                    "Calendar signature changed to \(signature, privacy: .public); resetting window"
                )
                viewModel.previewScrolledMonth(nil)
                resetWindow()
            }
            .onChange(of: realizedMonths) { _, realized in
                guard let day = pendingDayReveal else { return }
                let month = viewModel.engine.month(containing: day)
                if realized.contains(month) { revealRequestedDay(in: month, proxy: proxy) }
            }
            .onChange(of: scrollPosition) { _, position in
                guard let position else { return }
                if let anchor {
                    prefetch.scrollPositionChanged(
                        to: position, anchor: anchor, viewModel: viewModel)
                }
                // The header follows the gesture live; only the model waits for the scroll to
                // settle. Before the user's own first gesture this is a programmatic reveal,
                // which must never move the header.
                if settle.isUserScrolling { viewModel.previewScrolledMonth(position) }
                guard position != currentMonthIdentifier else { return }
                // Mid-gesture or mid-momentum, the `.idle` phase change settles once at the end.
                // Settling on every month crossed wrote the model ~100 times per fling,
                // invalidated every realized grid each time, and raced the still-moving scroll
                // position (see `synchronizeExternalNavigation`).
                guard !settle.isScrolling else { return }
                guard viewModel.engine.start(of: position) != nil else { return }
                scheduleScrollSettlement()
            }
        }
        // Recreate the reader with the UIKit scroll view so its proxy cannot retain stale
        // placement estimates. Native scrolling and window recentering keep this identity.
        .id(navigationRevision)
    }

    private var currentMonthIdentifier: MonthIdentifier {
        viewModel.visibleMonth
    }

    private func initializeWindow() {
        guard anchor == nil, contentWidth > 0 else { return }
        let current = currentMonthIdentifier
        logger.info(
            "Initializing vertical window at \(current.year, privacy: .public)-\(current.month, privacy: .public)"
        )
        // Observe visibility separately from the explicit navigation request, so initial
        // positioning does not race a user-position binding within the same layout pass.
        resetWindow(to: current)
    }

    /// Rebuilds the window when navigation arrives from outside the vertical scroll.
    private func synchronizeExternalNavigation(proxy: ScrollViewProxy, isTodayRequest: Bool = false)
    {
        let target = currentMonthIdentifier
        // A model change this view's own settlement produced is not external navigation. By the
        // time it arrives the list may have moved on, and treating it as external reset the window
        // and `scrollTo`'d back to the settled month — killing the scroll's momentum mid-fling.
        if !isTodayRequest, settle.consumeSettledMonth(target) {
            // A controlled calendar applies the settlement a render later, so the header kept
            // previewing it until now. If a new gesture began meanwhile, keep following that one.
            viewModel.previewScrolledMonth(settle.isUserScrolling ? scrollPosition : nil)
            logger.debug(
                "Ignoring self-originated navigation to \(target.year, privacy: .public)-\(target.month, privacy: .public)"
            )
            return
        }
        logger.info(
            "External navigation to \(target.year, privacy: .public)-\(target.month, privacy: .public); restoring position"
        )
        // Regenerate around the target so external navigation starts from a clean, centered window.
        settle.cancel()
        viewModel.previewScrolledMonth(nil)
        let calendar = viewModel.engine.calendar
        pendingDayReveal =
            calendar.isDateInToday(viewModel.currentDate)
            ? calendar.startOfDay(for: viewModel.currentDate) : nil
        if realizedMonths.contains(target), pendingDayReveal != nil {
            revealRequestedDay(in: target, proxy: proxy)
            return
        }
        if target == anchor {
            // A continuous scroll can leave the anchor month only partly visible. Changing its
            // selected date (Today, for example) must still restore the month to the viewport.
            withTransaction(Transaction(animation: nil)) {
                #if os(macOS)
                proxy.scrollTo(target, anchor: .top)
                #else
                navigationPosition.scrollTo(id: target, anchor: .top)
                #endif
            }
        } else {
            resetWindow()
        }
    }

    private func revealRequestedDay(in month: MonthIdentifier, proxy: ScrollViewProxy) {
        guard let day = pendingDayReveal, viewModel.engine.month(containing: day) == month else {
            return
        }
        pendingDayReveal = nil
        requestedAnchor = nil
        logger.debug("Revealing the requested day in the visible month")
        withTransaction(Transaction(animation: nil)) {
            #if os(macOS)
            proxy.scrollTo(MonthSnapshot.Day.identity(for: day), anchor: .center)
            #else
            navigationPosition.scrollTo(id: MonthSnapshot.Day.identity(for: day), anchor: .center)
            #endif
        }
    }

    /// Applies the final visible month after a user scroll settles. Intermediate positions only move
    /// the header (`previewScrolledMonth(_:)`); the model, which every realized grid observes, is
    /// navigated once at the end of the gesture.
    private func scheduleScrollSettlement() {
        settle.schedule { settleScrollPosition() }
    }

    private func settleScrollPosition() {
        // Programmatic month/day reveals can also expose part of a neighboring month.
        // Only a user's gesture may turn that visibility into a model navigation.
        guard settle.hasUserInteraction else { return }
        guard let position = scrollPosition, position != currentMonthIdentifier,
            viewModel.engine.start(of: position) != nil
        else {
            viewModel.previewScrolledMonth(nil)
            return
        }
        guard let date = viewModel.engine.navigationDate(in: position, preferredDay: 1) else {
            viewModel.previewScrolledMonth(nil)
            logger.error(
                "No navigable date in settled month \(position.year, privacy: .public)-\(position.month, privacy: .public)"
            )
            return
        }
        CalendarSignpost.scroll.measure("settleScrollPosition") {
            do {
                try viewModel.navigate(to: date)
                // Clears the preview once an owned model is on `position`; a controlled model
                // catches up a render later, and keeps the header on `position` until it does.
                viewModel.previewScrolledMonth(position)
                settle.recordSettled(position)
                recenterWindowIfNeeded(around: position)
                logger.debug(
                    "Settled on \(position.year, privacy: .public)-\(position.month, privacy: .public)"
                )
            } catch {
                viewModel.previewScrolledMonth(nil)
                logger.error(
                    "Failed to navigate to settled month", error: error,
                    context: "month=\(position.year)-\(position.month)")
            }
        }
    }

    /// Re-anchors the window on the settled month when the scroll came to rest far from the anchor
    /// and allowed months remain beyond the window's edge in that direction, so the next fling again
    /// has ``VerticalMonthWindow/radius`` months of room.
    ///
    /// Runs only after an idle settlement, never mid-scroll (growing or shifting a `LazyVStack`
    /// under an active scroll position is what the SDK mishandles). Stable month IDs let the native
    /// scroll position preserve the partially visible month when the window is re-centered.
    private func recenterWindowIfNeeded(around position: MonthIdentifier) {
        let engine = viewModel.engine
        guard let anchor, let anchorStart = engine.start(of: anchor),
            let positionStart = engine.start(of: position)
        else { return }
        // Approximate in lunisolar calendars (leap months), which the recenter margin absorbs.
        let offset =
            engine.calendar.dateComponents([.month], from: anchorStart, to: positionStart).month
            ?? 0
        let edge = offset < 0 ? -(VerticalMonthWindow.radius + 1) : VerticalMonthWindow.radius + 1
        let hasMonthsBeyondEdge = viewModel.monthIdentifier(offset: edge, from: anchor) != nil
        guard
            VerticalMonthWindow.shouldRecenter(
                offsetFromAnchor: offset, hasMonthsBeyondEdge: hasMonthsBeyondEdge)
        else { return }
        logger.info(
            "Re-centering vertical window on \(position.year, privacy: .public)-\(position.month, privacy: .public) (\(offset, privacy: .public) months from anchor)"
        )
        // Controlled models receive the navigation through a later render. Use the settled
        // position directly rather than reading their still-stale current month.
        resetWindow(to: position, scrollToTarget: false)
    }

    private func resetWindow(to target: MonthIdentifier? = nil, scrollToTarget: Bool = true) {
        // A new anchor invalidates the current sweep: prefetch offsets are relative to `anchor`, so
        // a stale sweep would warm entries keyed to an anchor the window no longer uses.
        prefetch.cancel()
        let target = target ?? currentMonthIdentifier
        months = VerticalMonthWindow.offsets.compactMap {
            viewModel.monthIdentifier(offset: $0, from: target)
        }
        anchor = target
        guard scrollToTarget else { return }
        logger.debug(
            "Scrolling to anchor \(target.year, privacy: .public)-\(target.month, privacy: .public)"
        )
        #if !os(macOS)
        navigationPosition = ScrollPosition(id: target, anchor: .top)
        navigationRevision += 1
        #endif
        requestedAnchor = target
    }
}

/// Coalesces scroll-driven model updates and brackets the gesture with a signpost interval.
///
/// Every month boundary the user crosses bumps `scrollPosition`, and applying each one to the model
/// immediately would mutate observable state several times per frame. Scheduling through a
/// generation counter collapses a burst into a single update, and keeping that counter in a
/// reference type means the bookkeeping itself never invalidates the enclosing view.
@MainActor
final class ScrollSettleCoordinator {
    private let logger = Logger.swiftUICalendar(for: ScrollSettleCoordinator.self)
    private var generation = 0
    private var scrollInterval: OSSignpostIntervalState?
    /// The month the most recent settlement wrote to the model, until its change is observed.
    private var settledMonth: MonthIdentifier?

    /// Whether a user gesture or its momentum is in progress (any non-idle scroll phase).
    private(set) var isScrolling = false
    /// Whether the scroll in progress is a user's gesture or its momentum, not a programmatic
    /// `.animating` scroll.
    private(set) var isUserScrolling = false
    private(set) var hasUserInteraction = false

    /// Remembers that `month` was written to the model by a settlement, not by external navigation.
    func recordSettled(_ month: MonthIdentifier) {
        settledMonth = month
    }

    /// Returns `true` (once) when `month` is the change the last settlement produced.
    func consumeSettledMonth(_ month: MonthIdentifier) -> Bool {
        defer { settledMonth = nil }
        guard let settledMonth, settledMonth == month else { return false }
        return true
    }

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
        isScrolling = phase != .idle
        switch phase {
        case .tracking, .interacting, .decelerating:
            isUserScrolling = true
            hasUserInteraction = true
        case .idle, .animating:
            isUserScrolling = false
        }
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
        isScrolling = false
        isUserScrolling = false
        hasUserInteraction = false
        settledMonth = nil
    }
}

/// Races ahead of a fast scroll's direction of travel, warming ``CalendarRenderCache`` for months
/// the vertical scroll has never realized before.
///
/// Reuse caching alone cannot remove the cost of a first-time realization — resolving a month
/// offset, building its day grid, and formatting its title. Profiling (Instruments, Animation
/// Hitches, fast scroll in the TCA sample) showed that cold-cache cluster dominating every other
/// per-frame cost. This coordinator turns a would-be miss (computed synchronously, expensively, in
/// the realizing frame) into a hit (computed ahead of time, off the main actor) by prefetching a
/// bounded window of upcoming offsets whenever the scroll position moves.
@MainActor
private final class MonthPrefetchCoordinator {
    /// How many months to warm ahead of the scroll direction. Large enough to stay ahead of a fast
    /// fling without the sweep exhausting itself mid-gesture; small enough not to spend CPU/battery
    /// warming months that may never be viewed.
    ///
    /// An eighth of the realized window: the sweep never aims to fill the window, only the stretch
    /// of it a single gesture can travel into, so the rest stays cold until the scroll approaches.
    private static let prefetchDistance = VerticalMonthWindow.radius / 8

    private let logger = Logger.swiftUICalendar(for: MonthPrefetchCoordinator.self)
    private var task: Task<Void, Never>?
    private var lastPosition: MonthIdentifier?

    /// Call on every `scrollPosition` change. Infers direction of travel from the previous
    /// position and reschedules the sweep from the latest position each time, so a sustained scroll
    /// keeps the warmed window ahead of the user rather than exhausting a single fixed sweep.
    func scrollPositionChanged(
        to position: MonthIdentifier, anchor: MonthIdentifier, viewModel: CalendarViewModel
    ) {
        defer { lastPosition = position }
        guard let previous = lastPosition, previous != position else { return }

        let engine = viewModel.engine
        let calendar = engine.calendar
        guard let previousStart = engine.start(of: previous),
            let currentStart = engine.start(of: position)
        else { return }
        let direction = currentStart > previousStart ? 1 : -1

        // The `ForEach` resolves every row via `monthIdentifier(offset:from: anchor)`, so a
        // prefetched offset only lands in the same `CalendarRenderCache` offset-cache entry the
        // hot path will look up if it's computed relative to the same anchor. This recovers the
        // scroll position's approximate offset from that anchor; an off-by-one estimate is
        // harmless since the sweep covers a range, not a single offset. In lunisolar calendars
        // (Chinese leap months) `dateComponents` and `CalendarEngine.month(offset:from:)` can
        // disagree by roughly one month per three years from the anchor; that drift stays well
        // inside `prefetchDistance` for any realistic scroll distance.
        let currentOffset: Int
        if let anchorStart = engine.start(of: anchor) {
            currentOffset =
                calendar.dateComponents([.month], from: anchorStart, to: currentStart)
                .month ?? 0
        } else {
            currentOffset = 0
        }

        schedule(
            direction: direction, currentOffset: currentOffset, anchor: anchor, calendar: calendar,
            engine: engine, renderCache: viewModel.renderCache)
    }

    private func schedule(
        direction: Int, currentOffset: Int, anchor: MonthIdentifier, calendar: Calendar,
        engine: CalendarEngine, renderCache: CalendarRenderCache
    ) {
        task?.cancel()
        let offsets = (1...Self.prefetchDistance).map { currentOffset + direction * $0 }
        logger.debug(
            "Prefetching \(offsets.count, privacy: .public) months from offset \(currentOffset, privacy: .public), direction \(direction, privacy: .public)"
        )
        let logger = logger
        task = Task.detached(priority: .utility) {
            for (index, offset) in offsets.enumerated() {
                if Task.isCancelled {
                    logger.debug(
                        "Prefetch sweep cancelled after \(index, privacy: .public) of \(offsets.count, privacy: .public) months"
                    )
                    return
                }
                await renderCache.prefetchMonth(
                    offset: offset, from: anchor, calendar: calendar, engine: engine)
            }
            logger.debug(
                "Prefetch sweep finished \(offsets.count, privacy: .public) months from offset \(currentOffset, privacy: .public)"
            )
        }
    }

    /// Cancels any in-flight sweep. Previously warmed entries stay cached — this only stops
    /// continuing to prefetch from a sweep that's no longer relevant (view disappeared, the window
    /// reset to a new anchor, or the calendar signature changed).
    func cancel() {
        task?.cancel()
        task = nil
        lastPosition = nil
    }
}

/// Plain inputs instead of `@Environment(Type.self)`: this view is created once per realized row,
/// and every observable `@Environment` declaration instantiates a generic key path on creation.
private struct VerticalMonthView: View {
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarConfiguration) private var configuration

    let item: VerticalMonthItem
    let locale: Locale
    let typography: Typography
    let layoutWidth: CGFloat?
    let keyboard: CalendarKeyboardCursor?

    // Matches the width `CalendarBodyView` resolves for its own grid below, so the title lines up
    // with the day columns instead of the full row width — the two diverge whenever the resolved
    // cell size saturates `maxCellSize` (e.g. a wide landscape layout), which leaves the grid
    // narrower than the row and centered within it.
    private var gridWidth: CGFloat {
        CalendarGridLayout(
            containerWidth: layoutWidth ?? metrics.minCalendarWidth,
            metrics: metrics,
            sizing: configuration.gridSizing
        ).gridWidth
    }

    var body: some View {
        VStack(spacing: metrics.itemSpacing) {
            HStack {
                Text(item.monthTitle)
                    .font(typography.monthHeaderFont)
                Text(NumberFormatter.formatYear(item.id.year, locale: locale))
                    .font(typography.monthHeaderFont)
                Spacer(minLength: 0)
            }
            .frame(width: gridWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(
                CalendarAccessibilityID.verticalMonthHeader(
                    year: item.id.year, month: item.id.month)
            )

            CalendarBodyView(
                monthIdentifier: item.id,
                hideOverflowDays: true,
                navigatesOnOverflowTap: false,
                layoutWidth: layoutWidth, keyboard: keyboard
            )
        }
    }
}

struct VerticalMonthItem: Identifiable, Equatable {
    let id: MonthIdentifier
    let monthTitle: String
}

/// The slice of months the vertical list realizes around its anchor.
///
/// SwiftUI's lazy stack pays per-update bookkeeping (walking `ForEach` items, estimating placements,
/// searching for `scrollTo` targets) in proportion to the total row count, not the visible rows.
/// Profiling a fast scroll showed ±1,500 months producing about 94 interaction delays against 2 for
/// a ±120 window. ±240 keeps that cost low while leaving 20 years of room per fling, and
/// re-centering after each settlement keeps that room available wherever the scroll rests.
enum VerticalMonthWindow {
    /// A month remains current while at least this fraction is visible at the top of the list.
    static let visibilityThreshold = 0.01
    /// Months realized on each side of the anchor.
    static let radius = 240
    /// How far from the anchor a settled scroll must rest before the window re-centers.
    ///
    /// A quarter of ``radius``: recentering that late keeps a settled scroll from re-centering on
    /// every month boundary, and that early guarantees a whole quarter-window of room in the
    /// direction of travel before the next re-center.
    static let recenterDistance = radius / 4
    /// Materialized once. A `ForEach` over a `ClosedRange` walks it through unspecialized generic
    /// `Collection` witnesses (instantiating metadata as it goes) on every list update.
    static let offsets = Array(-radius...radius)

    /// Whether a scroll that settled `offsetFromAnchor` months from the anchor should re-center.
    ///
    /// - Parameters:
    ///   - offsetFromAnchor: Months between the anchor and the settled month.
    ///   - hasMonthsBeyondEdge: Whether allowed months exist past the window edge in that
    ///     direction. When the date range ends inside the window, re-centering gains nothing.
    static func shouldRecenter(offsetFromAnchor: Int, hasMonthsBeyondEdge: Bool) -> Bool {
        abs(offsetFromAnchor) >= recenterDistance && hasMonthsBeyondEdge
    }
}

#Preview {
    CalendarBodyVerticalView()
        .environment(CalendarViewModel.test(identifier: .persian, selection: .range(Date(), nil)))
        .environment(Theme.default)
        .environment(Typography.default)
}

extension View {
    @ViewBuilder
    fileprivate func calendarVerticalScrollPosition(
        navigation: Binding<ScrollPosition>, month: Binding<MonthIdentifier?>
    ) -> some View {
        #if os(macOS)
        scrollPosition(id: month, anchor: .top)
        #else
        scrollPosition(navigation, anchor: .top)
        #endif
    }
}
