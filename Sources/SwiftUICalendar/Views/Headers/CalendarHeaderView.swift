import SwiftUI
import SwiftUICalendarAccessibility

struct CalendarHeaderView: View {

    @Environment(CalendarViewModel.self) var model
    @Environment(Typography.self) var typography
    @Environment(\.calendarMetrics) private var metrics

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: metrics.headerControlSpacing) {
                CalendarHeaderMonthView()
                    .id("row-month")
                CalendarHeaderYearView()
                    .id("row-year")
                macOSTodayButton
            }
            VStack {
                CalendarHeaderMonthView()
                    .id("stack-month")
                CalendarHeaderYearView()
                    .id("stack-year")
                macOSTodayButton
            }
        }
        .font(typography.headerFont)
    }

    @ViewBuilder
    private var macOSTodayButton: some View {
        #if os(macOS)
        // Today selects the current day in single-selection mode on both platforms.
        Button("Calendar.Today".localized) {
            model.goToToday()
        }
        .fixedSize()
        .accessibilityIdentifier(CalendarAccessibilityID.todayButton)
        #endif
    }
}

#Preview("Default") {
    CalendarHeaderView()
        .environment(CalendarViewModel.test(identifier: .persian))
        .environment(Typography.default)
}

#Preview("Persian") {
    CalendarHeaderView()
        .environment(CalendarViewModel.test(identifier: .persian))
        .environment(Typography.default)
}
