import SwiftUI

/// A second complete month sharing navigation, selection, and day rendering with the primary panel.
struct CalendarCompanionMonthView: View {
    let month: MonthIdentifier
    let keyboard: CalendarKeyboardCursor?
    @Environment(CalendarViewModel.self) private var model
    @Environment(Typography.self) private var typography
    @Environment(\.calendarConfiguration) private var configuration
    @Environment(\.calendarMetrics) private var metrics
    @Environment(\.calendarContentWidth) private var contentWidth
    @Environment(\.calendarPanelHeaders) private var panelHeaders

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: CalendarScrollChrome.showsIndicators) {
                VStack(spacing: metrics.rowSpacing) {
                    if configuration.showsHeader {
                        Text(model.monthSnapshot(for: month)?.title ?? "")
                            .font(typography.headerFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: metrics.headerRowHeight)
                            .frame(
                                minHeight: panelHeaders?.primaryHeight ?? 0,
                                alignment: .bottomLeading
                            )
                            .accessibilityAddTraits(.isHeader)
                    } else {
                        Color.clear.frame(height: panelHeaders?.primaryHeight ?? 0)
                    }
                    CalendarBodyView(
                        monthIdentifier: month, hideOverflowDays: true,
                        navigatesOnOverflowTap: false, layoutWidth: contentWidth, keyboard: keyboard
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: keyboard?.scrollRequest) { _, request in
                guard keyboard?.isActive == true, let request,
                    model.engine.month(containing: request.dayStart) == month
                else { return }
                proxy.scrollTo(request.identity)
            }
        }
    }
}
