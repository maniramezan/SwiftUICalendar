import SwiftUI

struct CalendarHeaderView: View {

  @Environment(CalendarViewModel.self) var model
  @Environment(Typography.self) var typography

  var body: some View {
    ViewThatFits {
      HStack {
        CalendarHeaderMonthView()
        CalendarHeaderYearView()
        macOSTodayButton
      }
      #if !os(macOS)
        VStack {
          CalendarHeaderMonthView()
          CalendarHeaderYearView()
        }
      #endif
    }
    .font(typography.headerFont)
  }

  @ViewBuilder
  private var macOSTodayButton: some View {
    #if os(macOS)
      // Navigate to today without mutating the user's selection, matching the iOS Today button.
      Button("Calendar.Today".localized) {
        model.goToToday()
      }
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
