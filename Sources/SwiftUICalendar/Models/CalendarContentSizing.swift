import SwiftCommons
import SwiftUI

/// Inputs for a custom renderer's minimum readable cell size.
public struct CalendarDaySizingContext {
    public let dynamicTypeSize: DynamicTypeSize
    public let typography: Typography
    public let calendar: Calendar
}

/// Measures representative labels once per calendar, outside the realized day-cell loop.
struct CalendarContentSizing: ViewModifier {
    @Environment(CalendarViewModel.self) private var model
    @Environment(Theme.self) private var theme
    @Environment(Typography.self) private var typography
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var primary: CGSize = .zero
    @State private var secondary: CGSize = .zero
    @State private var weekday: CGSize = .zero
    @State private var secondaryLabelCache = SecondaryLabelCache()

    private var isSquare: Bool {
        if case .square = theme.day.renderer { return true }
        return false
    }

    private var fonts: DayViewTypography {
        typography.dayViewTypography(for: isSquare ? DayViewType.squareDual : DayViewType.circle)
    }

    private var labels: [String] {
        (1...31).map { NumberFormatter.formatDay($0, locale: model.locale) }
    }

    /// Distinct secondary labels across the visible month and its neighbors.
    ///
    /// The minimum cell size is applied to the whole calendar, and several months can be on screen at
    /// once, so measuring only the visible month made the grid resize whenever a wider label scrolled
    /// into view. The neighbors cover the months a pager or a vertical scroll reveals next. Secondary
    /// labels are day numbers or names that repeat from month to month, so this set is effectively
    /// the same wherever the calendar rests.
    private var secondaryLabels: [String] {
        let mode = theme.day.secondaryLabelMode
        let key = "\(model.calendarSignature)|\(String(describing: mode))"
        var seen = Set<String>()
        return [-1, 0, 1]
            .compactMap { model.monthIdentifier(offset: $0) }
            .flatMap { month in
                secondaryLabelCache.labels(for: month, key: key) {
                    model.monthSnapshot(for: month)?.days.compactMap { day in
                        day.date.flatMap { mode.label(for: $0) }
                    } ?? []
                }
            }
            .filter { seen.insert($0).inserted }
    }

    private var minimumCell: CGSize {
        if case .custom = theme.day.renderer, let provider = theme.day.minimumContentSize {
            let size = provider(
                CalendarDaySizingContext(
                    dynamicTypeSize: dynamicTypeSize, typography: typography,
                    calendar: model.engine.calendar))
            return CGSize(
                width: size.width.isFinite
                    ? max(metrics.minimumHitTarget, size.width) : metrics.minimumHitTarget,
                height: size.height.isFinite
                    ? max(metrics.minimumHitTarget, size.height) : metrics.minimumHitTarget)
        }
        if isSquare {
            return CGSize(
                width: max(primary.width, secondary.width) + 2 * metrics.dayContentPadding,
                height: primary.height + secondary.height + metrics.dayLabelSpacing + 2
                    * metrics.dayContentPadding)
        }
        return CGSize(
            width: primary.width * sqrt(2) + 2 * metrics.tightPadding,
            height: primary.height * sqrt(2) + 2 * metrics.tightPadding)
    }

    func body(content: Content) -> some View {
        content
            .environment(
                \.calendarMetrics, metrics.resolvingContent(cell: minimumCell, weekday: weekday)
            )
            .overlay(alignment: .topLeading) {
                ZStack {
                    CalendarLabelMeasure(labels: labels, font: fonts.primaryFont, size: $primary)
                    CalendarLabelMeasure(
                        labels: isSquare ? secondaryLabels : [], font: fonts.secondaryFont,
                        size: $secondary)
                    CalendarLabelMeasure(
                        labels: model.headerTitles, font: typography.weekdayHeaderFont,
                        size: $weekday)
                }
                .hidden()
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            }
    }
}

/// Remembers each month's secondary labels. Resolving a label builds a `Calendar` and a
/// `DateFormatter` per day, so the sizing pass must not repeat that for every body evaluation.
@MainActor
final class SecondaryLabelCache {
    private var key = ""
    private var labelsByMonth: [MonthIdentifier: [String]] = [:]

    func labels(
        for month: MonthIdentifier, key: String, resolve: () -> [String]
    ) -> [String] {
        if self.key != key {
            self.key = key
            labelsByMonth.removeAll()
        }
        if let cached = labelsByMonth[month] { return cached }
        let labels = resolve()
        labelsByMonth[month] = labels
        return labels
    }
}

private struct CalendarLabelMeasure: View {
    let labels: [String]
    let font: Font
    @Binding var size: CGSize

    var body: some View {
        ZStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                Text(label).font(font).fixedSize()
            }
        }
        .fixedSize()
        .onGeometryChange(for: CGSize.self) {
            $0.size
        } action: {
            size = $0
        }
    }
}
