import SwiftUI
import SwiftUICalendar

struct BookingCalendar: View {
  @State private var calendar = CalendarViewModel(
    calendarIdentifier: .gregorian,
    selection: .range(nil, nil)
  )

  var body: some View {
    CalendarView(model: calendar, theme: theme)
      .frame(minHeight: 420)
  }

  private var theme: Theme {
    let theme = Theme()
    theme.scrollMode = .horizontal
    theme.horizontalHeightMode = .hugContent
    theme.day.selectedBackgroundColor = .indigo
    theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
    return theme
  }
}
