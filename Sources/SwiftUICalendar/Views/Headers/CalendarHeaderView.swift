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
      Button("Calendar.Today".localized) {
        model.currentDate = Date()
        model.select(model.currentDate)
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
