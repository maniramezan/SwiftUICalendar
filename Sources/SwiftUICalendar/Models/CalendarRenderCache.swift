import Foundation
import OSLog
import SwiftCommons

/// Memoizes the `Calendar` and `DateFormatter` work that the scrolling calendar repeats every frame.
///
/// Resolving one month grid costs roughly six `Calendar` calls per day plus a `NumberFormatter`
/// lookup — around 300 operations for a six-row month. A vertically scrolling calendar keeps six to
/// eight months realized, and every model mutation re-evaluates all of their bodies, so an uncached
/// grid lands ~2,500 calendar operations inside a single frame and the scroll visibly stalls.
///
/// The cache is deliberately **not** owned by ``CalendarViewModel``. In the externally owned
/// (TCA) integration `CalendarView` builds a fresh rendering projection on every store mutation, so
/// an instance-scoped cache starts cold on every frame — precisely when the calendar is busiest.
/// Keying on the calendar/locale/time-zone signature instead makes the memoized work survive those
/// rebuilds while still isolating distinct calendar systems from one another.
///
/// Entries hold only calendar *geometry* — the dates, labels, and in-month flags of a month. `today`
/// and the current selection are applied on read (see ``CalendarViewModel/monthSnapshot(for:)``), so
/// tapping a day never invalidates a grid.
@MainActor
final class CalendarRenderCache {

    /// The process-wide cache. Shared so rendering projections rebuilt per frame stay warm.
    static let shared = CalendarRenderCache()

    /// Upper bound on retained month grids. Twelve years of scrollback at ~36KB per entry.
    private static let monthGeometryLimit = 144
    /// Upper bound on retained month-offset resolutions.
    private static let monthOffsetLimit = 4_096

    private let logger = Logger.swiftUICalendar(for: CalendarRenderCache.self)

    // MARK: - Stored entries

    /// A month grid stripped of everything that changes without the calendar changing.
    struct MonthGeometry: Equatable, Sendable {
        struct Day: Equatable, Sendable {
            let id: String
            let date: Date
            /// `date` snapped to the start of its day, precomputed so `isToday` and selection checks are
            /// plain `Date` comparisons rather than per-day `Calendar` work.
            let dayStart: Date
            let day: Int
            let dayLabel: String
            let month: Int
            let year: Int
            let isInDisplayedMonth: Bool
        }

        let days: [Day]
    }

    private struct MonthKey: Hashable {
        let signature: String
        let month: MonthIdentifier
    }

    private struct OffsetKey: Hashable {
        let signature: String
        let month: MonthIdentifier
        let offset: Int
        /// The engine's allowed dates. Offsets resolve to `nil` outside them, so identical calendars
        /// with different `CalendarState.dateRange`s must not share entries.
        let bounds: Range<Date>
    }

    private struct TitleKey: Hashable {
        let signature: String
        let year: Int
        let month: Int
        let isLeapMonth: Bool

        init(signature: String, month: MonthIdentifier) {
            self.signature = signature
            self.year = month.year
            self.month = month.month
            self.isLeapMonth = month.isLeapMonth
        }
    }

    private var monthGeometry: [MonthKey: MonthGeometry] = [:]
    private var monthGeometryOrder: [MonthKey] = []
    private var monthOffsets: [OffsetKey: MonthIdentifier?] = [:]
    private var monthOffsetOrder: [OffsetKey] = []
    private var monthTitles: [TitleKey: String] = [:]
    private var monthTitlesOrder: [TitleKey] = []
    /// Upper bound on retained month titles.
    private static let monthTitleLimit = 4_096

    // MARK: - Signature

    /// Identifies every input that changes a month's geometry.
    ///
    /// The time zone is part of the key because it moves the wall-clock instants the grid stores, and
    /// the locale is because it selects the numbering system used for day labels.
    nonisolated static func signature(for calendar: Calendar) -> String {
        let locale = calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
        return "\(calendar.identifier)|\(locale.identifier)|\(calendar.timeZone.identifier)"
    }

    // MARK: - Month geometry

    /// Returns the cached geometry for `month`, resolving and storing it on a miss.
    ///
    /// - Returns: The month's geometry, or `nil` when the identifier does not resolve in `calendar`.
    func monthGeometry(
        for month: MonthIdentifier, calendar: Calendar, engine: CalendarEngine
    ) -> MonthGeometry? {
        monthGeometry(
            for: month, calendar: calendar, signature: Self.signature(for: calendar), engine: engine
        )
    }

    /// Same as ``monthGeometry(for:calendar:engine:)`` with a precomputed `signature`, which must
    /// equal ``signature(for:)`` of `calendar` (see ``CalendarState/renderSignature``). The render
    /// path uses this so it never rebuilds the signature string per lookup.
    func monthGeometry(
        for month: MonthIdentifier, calendar: Calendar, signature: String, engine: CalendarEngine
    ) -> MonthGeometry? {
        let key = MonthKey(signature: signature, month: month)
        if let cached = monthGeometry[key] {
            return cached
        }

        guard
            let geometry = Self.computeMonthGeometry(for: month, calendar: calendar, engine: engine)
        else {
            logger.debug(
                "Month geometry unresolved: \(month.year, privacy: .public)-\(month.month, privacy: .public)"
            )
            return nil
        }
        store(geometry, for: key)
        return geometry
    }

    // MARK: - Month offsets

    /// Returns the month `offset` months from `month`, memoizing both hits and misses.
    ///
    /// The vertical calendar resolves one offset per realized row on every body pass, and each
    /// resolution costs six `Calendar` round trips. Memoizing turns that into a dictionary lookup.
    func month(
        offset: Int, from month: MonthIdentifier, calendar: Calendar, engine: CalendarEngine
    ) -> MonthIdentifier? {
        self.month(
            offset: offset, from: month, signature: Self.signature(for: calendar), engine: engine)
    }

    /// Same as ``month(offset:from:calendar:engine:)`` with a precomputed `signature`; see
    /// ``monthGeometry(for:calendar:signature:engine:)``.
    func month(
        offset: Int, from month: MonthIdentifier, signature: String, engine: CalendarEngine
    ) -> MonthIdentifier? {
        let key = OffsetKey(
            signature: signature, month: month, offset: offset, bounds: engine.supportedDates)
        // A cached miss is stored as `.some(nil)`; only an absent key is a cache miss.
        if let cached = monthOffsets[key] {
            return cached
        }

        let resolved = Self.computeMonthOffset(offset: offset, from: month, engine: engine)
        store(resolved, for: key)
        return resolved
    }

    // MARK: - Month titles

    /// Returns the localized month title for `identifier`, memoizing per calendar signature.
    ///
    /// Formerly a per-`CalendarViewModel` cache (`monthTitleCache`); moved here so a title warmed
    /// by background prefetch is visible to every model instance reading the same calendar system,
    /// not just the one that happened to prefetch it.
    func monthTitle(for identifier: MonthIdentifier, calendar: Calendar) -> String? {
        monthTitle(for: identifier, calendar: calendar, signature: Self.signature(for: calendar))
    }

    /// Same as ``monthTitle(for:calendar:)`` with a precomputed `signature`; see
    /// ``monthGeometry(for:calendar:signature:engine:)``.
    func monthTitle(
        for identifier: MonthIdentifier, calendar: Calendar, signature: String
    ) -> String? {
        let key = TitleKey(signature: signature, month: identifier)
        if let cached = monthTitles[key] {
            return cached
        }
        guard let title = Self.computeMonthTitle(for: identifier, calendar: calendar) else {
            return nil
        }
        store(title, for: key)
        return title
    }

    // MARK: - Pure computation (background-safe)

    /// Resolves a month's day grid without touching any cache state.
    ///
    /// `Calendar` is a value type safe to use concurrently from independently held copies, and
    /// `NumberFormatter.formatDay` is backed by SwiftCommons' thread-local `FormatterCache` — so
    /// this is safe to call from a background thread, which ``prefetchMonth(offset:from:calendar:engine:)``
    /// does to warm the cache ahead of a fast scroll without costing a rendering frame.
    nonisolated static func computeMonthGeometry(
        for month: MonthIdentifier, calendar: Calendar, engine: CalendarEngine
    ) -> MonthGeometry? {
        CalendarSignpost.rendering.measure("resolveMonthGeometry") {
            guard let start = engine.start(of: month),
                let count = calendar.range(of: .day, in: .month, for: start)?.count
            else {
                return nil
            }

            let locale = calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
            let leading = calendar.component(.weekday, from: start) - 1
            let total = ((leading + count + 6) / 7) * 7
            let days = (0..<total).compactMap { index -> MonthGeometry.Day? in
                guard let date = calendar.date(byAdding: .day, value: index - leading, to: start)
                else {
                    return nil
                }
                let day = calendar.component(.day, from: date)
                return MonthGeometry.Day(
                    id: "day-\(date.timeIntervalSinceReferenceDate)",
                    date: date,
                    dayStart: calendar.startOfDay(for: date),
                    day: day,
                    dayLabel: NumberFormatter.formatDay(day, locale: locale),
                    month: calendar.component(.month, from: date),
                    year: calendar.component(.year, from: date),
                    isInDisplayedMonth: index >= leading && index < leading + count)
            }

            return MonthGeometry(days: days)
        }
    }

    /// Resolves the month `offset` months from `month` without touching any cache state. Safe to
    /// call from a background thread; see ``computeMonthGeometry(for:calendar:engine:)``.
    nonisolated static func computeMonthOffset(
        offset: Int, from month: MonthIdentifier, engine: CalendarEngine
    ) -> MonthIdentifier? {
        CalendarSignpost.rendering.measure("resolveMonthOffset") {
            engine.month(offset: offset, from: month)
        }
    }

    /// Resolves a month's localized title without touching any cache state. Safe to call from a
    /// background thread; see ``computeMonthGeometry(for:calendar:engine:)``.
    nonisolated static func computeMonthTitle(
        for month: MonthIdentifier, calendar: Calendar
    ) -> String? {
        CalendarSignpost.rendering.measure("resolveMonthTitle") {
            guard let date = CalendarEngine(calendar: calendar).start(of: month) else { return nil }
            return DateFormatter.formatter(dateFormat: "LLLL", calendar: calendar).string(
                from: date)
        }
    }

    // MARK: - Prefetching

    /// Warms the offset, geometry, and title caches for `offset` months from `month`, off the main
    /// actor.
    ///
    /// This exists because reuse caching alone cannot remove the cost of realizing a month the
    /// vertical scroll has never shown before — resolving its offset, building its ~300-operation
    /// day grid, and formatting its title. Profiling a fast scroll (Instruments, Animation Hitches)
    /// showed that cold-cache cluster dwarfing every other per-frame cost. The fix is to compute it
    /// ahead of the frame that needs it: `CalendarBodyVerticalView` calls this from a background
    /// task racing ahead of the scroll direction, so by the time the row actually realizes, this
    /// method (or the synchronous hot path, whichever wins the race) has already stored the result.
    ///
    /// `nonisolated` so the expensive computation genuinely runs on the calling (background) thread
    /// rather than being funneled through the main actor's executor. Cache state is only touched on
    /// `MainActor`: one hop reads what is already cached, and at most one more stores whatever was
    /// missing. Consecutive sweeps overlap by all but one month, so a month that the render path or
    /// an earlier sweep already warmed costs only the lookup hop, never a recomputation.
    nonisolated func prefetchMonth(
        offset: Int, from month: MonthIdentifier, calendar: Calendar, engine: CalendarEngine
    ) async {
        guard !Task.isCancelled else { return }
        let signature = Self.signature(for: calendar)
        let offsetKey = OffsetKey(
            signature: signature, month: month, offset: offset, bounds: engine.supportedDates)

        let cachedOffset = await MainActor.run { self.monthOffsets[offsetKey] }
        let offsetWasCached = cachedOffset != nil
        let resolved: MonthIdentifier? =
            if let cachedOffset {
                cachedOffset
            } else {
                Self.computeMonthOffset(offset: offset, from: month, engine: engine)
            }

        guard let resolved else {
            // An unresolvable offset is memoized as a miss, exactly as the render path does.
            if !offsetWasCached, !Task.isCancelled {
                await MainActor.run { self.store(nil, for: offsetKey) }
            }
            return
        }
        guard !Task.isCancelled else { return }

        let geometryKey = MonthKey(signature: signature, month: resolved)
        let titleKey = TitleKey(signature: signature, month: resolved)
        let (hasGeometry, hasTitle) = await MainActor.run {
            (self.monthGeometry[geometryKey] != nil, self.monthTitles[titleKey] != nil)
        }
        guard !offsetWasCached || !hasGeometry || !hasTitle else { return }

        let geometry =
            hasGeometry
            ? nil : Self.computeMonthGeometry(for: resolved, calendar: calendar, engine: engine)
        guard !Task.isCancelled else { return }
        let title = hasTitle ? nil : Self.computeMonthTitle(for: resolved, calendar: calendar)
        guard !Task.isCancelled else { return }

        await MainActor.run {
            if !offsetWasCached { self.store(resolved, for: offsetKey) }
            if let geometry { self.store(geometry, for: geometryKey) }
            if let title { self.store(title, for: titleKey) }
        }
    }

    // MARK: - Formatters

    /// Returns a `DateFormatter` configured for `calendar` and `format`, reusing it across calls.
    ///
    /// `DateFormatter` construction dominates month-title resolution. Delegating to SwiftCommons'
    /// `FormatterCache`-backed helper keeps title lookups cheap even when the owning view model is
    /// rebuilt every frame, without this package maintaining its own duplicate formatter cache.
    func formatter(format: String, calendar: Calendar) -> DateFormatter {
        DateFormatter.formatter(dateFormat: format, calendar: calendar)
    }

    /// Returns a `DateFormatter` configured from a localized date-format template (see
    /// `setLocalizedDateFormatFromTemplate`), reusing it across calls.
    ///
    /// Resolving a template into a concrete pattern is a locale/CLDR lookup, considerably more
    /// expensive than `formatter(format:calendar:)`'s literal pattern. Every accessible day cell
    /// resolves one on read (`CalendarDayContext.accessibilityLabel`), so leaving it unmemoized
    /// dominated scroll frame time — this was the largest single cost in a fast-scroll profile.
    func templateFormatter(template: String, calendar: Calendar) -> DateFormatter {
        DateFormatter.formatter(template: template, calendar: calendar)
    }

    // MARK: - Diagnostics

    /// Number of retained month grids. Exposed for tests and log instrumentation.
    var monthGeometryCount: Int { monthGeometry.count }
    /// Number of retained month-offset resolutions. Exposed for tests and log instrumentation.
    var monthOffsetCount: Int { monthOffsets.count }
    /// Number of retained month titles. Exposed for tests and log instrumentation.
    var monthTitleCount: Int { monthTitles.count }
    /// Total entries across the eviction order lists. Equals the sum of the three counts above
    /// whenever bookkeeping is consistent; exposed for tests.
    var evictionOrderCount: Int {
        monthGeometryOrder.count + monthOffsetOrder.count + monthTitlesOrder.count
    }

    /// Drops every entry. Used by tests; also safe to call to reclaim memory under pressure.
    func removeAll() {
        monthGeometry.removeAll(keepingCapacity: true)
        monthGeometryOrder.removeAll(keepingCapacity: true)
        monthOffsets.removeAll(keepingCapacity: true)
        monthOffsetOrder.removeAll(keepingCapacity: true)
        monthTitles.removeAll(keepingCapacity: true)
        monthTitlesOrder.removeAll(keepingCapacity: true)
        logger.debug("Render cache cleared")
    }

    // MARK: - Eviction

    // Each `store` appends to its order list only when the key is new. Background prefetch and the
    // render path can both finish the same entry; appending again would grow the order list without
    // bound and make eviction drop a freshly re-stored key ahead of genuinely older ones.

    private func store(_ geometry: MonthGeometry, for key: MonthKey) {
        guard monthGeometry.updateValue(geometry, forKey: key) == nil else { return }
        monthGeometryOrder.append(key)
        evictOldest(
            from: &monthGeometry, order: &monthGeometryOrder, limit: Self.monthGeometryLimit,
            label: "month geometry")
    }

    private func store(_ identifier: MonthIdentifier?, for key: OffsetKey) {
        guard monthOffsets.updateValue(identifier, forKey: key) == nil else { return }
        monthOffsetOrder.append(key)
        evictOldest(
            from: &monthOffsets, order: &monthOffsetOrder, limit: Self.monthOffsetLimit,
            label: "month offsets")
    }

    private func store(_ title: String, for key: TitleKey) {
        guard monthTitles.updateValue(title, forKey: key) == nil else { return }
        monthTitlesOrder.append(key)
        evictOldest(
            from: &monthTitles, order: &monthTitlesOrder, limit: Self.monthTitleLimit,
            label: "month titles")
    }

    /// Trims the oldest entries once `storage` exceeds `limit`, in insertion order.
    private func evictOldest<Key: Hashable, Value>(
        from storage: inout [Key: Value], order: inout [Key], limit: Int, label: StaticString
    ) {
        guard storage.count > limit else { return }
        var index = 0
        while storage.count > limit, index < order.count {
            storage.removeValue(forKey: order[index])
            index += 1
        }
        order.removeFirst(index)
        logger.debug("Evicted \(index, privacy: .public) \(label, privacy: .public) cache entries")
    }
}
