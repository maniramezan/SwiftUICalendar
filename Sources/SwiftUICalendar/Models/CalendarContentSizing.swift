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

    private var secondaryLabels: [String] {
        model.monthSnapshot(for: model.visibleMonth)?.days.compactMap { day in
            day.date.flatMap { theme.day.secondaryLabelMode.label(for: $0) }
        } ?? []
    }

    private var minimumCell: CGSize {
        if case .custom = theme.day.renderer, let provider = theme.day.minimumContentSize {
            let size = provider(
                CalendarDaySizingContext(
                    dynamicTypeSize: dynamicTypeSize, typography: typography,
                    calendar: model.engine.calendar))
            return CGSize(
                width: size.width.isFinite ? max(44, size.width) : 44,
                height: size.height.isFinite ? max(44, size.height) : 44)
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
