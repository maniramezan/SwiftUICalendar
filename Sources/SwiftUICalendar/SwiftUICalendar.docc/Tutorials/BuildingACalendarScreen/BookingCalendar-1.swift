import SwiftUI
import SwiftUICalendar

struct BookingCalendar: View {
  @State private var calendar = CalendarViewModel(
    calendarIdentifier: .gregorian,
    selection: .range(nil, nil)
  )

  var body: some View {
    CalendarView(model: calendar)
      .frame(minHeight: 420)
  }
}
