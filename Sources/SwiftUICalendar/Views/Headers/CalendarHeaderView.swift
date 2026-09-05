import SwiftUI

struct CalendarHeaderView: View {

  @Environment(CalendarViewModel.self) var model
  @Environment(Typography.self) var typography

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 3) {
        CalendarHeaderMonthView()
          .id("row-month")
        CalendarHeaderYearView()
          .id("row-year")
        macOSTodayButton
      }
      #if !os(macOS)
        VStack {
          CalendarHeaderMonthView()
            .id("stack-month")
          CalendarHeaderYearView()
            .id("stack-year")
        }
      #endif
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
