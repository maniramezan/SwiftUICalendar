import SwiftUI
import SwiftUICalendarAccessibility

struct CalendarHeaderView: View {

    @Environment(Typography.self) var typography
    @Environment(\.calendarMetrics) private var metrics

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: metrics.headerControlSpacing) {
                CalendarHeaderMonthView()
                    .id("row-month")
                CalendarHeaderYearView()
                    .id("row-year")
                CalendarHeaderTodayButton()
            }
            VStack {
                CalendarHeaderMonthView()
                    .id("stack-month")
                CalendarHeaderYearView()
                    .id("stack-year")
                CalendarHeaderTodayButton()
            }
        }
        .font(typography.headerFont)
    }
}

/// The header's Today button, shown only on macOS where the header owns it.
private struct CalendarHeaderTodayButton: View {
    @Environment(CalendarViewModel.self) private var model

    var body: some View {
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
        .environment(CalendarViewModel.test(identifier: .gregorian))
        .environment(Typography.default)
}

#Preview("Persian") {
    CalendarHeaderView()
        .environment(CalendarViewModel.test(identifier: .persian))
        .environment(Typography.default)
}
