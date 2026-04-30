import SwiftUI
import SwiftUICalendar

struct BookingCalendar: View {
  @State private var calendar = CalendarViewModel(
    calendarIdentifier: .gregorian,
    selection: .range(nil, nil)
  )

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      CalendarView(model: calendar, theme: theme)
        .frame(minHeight: 420)

      Text(selectionSummary)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  private var theme: Theme {
    let theme = Theme()
    theme.scrollMode = .horizontal
    theme.horizontalHeightMode = .hugContent
    theme.day.selectedBackgroundColor = .indigo
    theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
    return theme
  }

  private var selectionSummary: String {
    switch calendar.selection {
    case .single(let date):
      return date?.formatted(date: .abbreviated, time: .omitted) ?? "No date selected"
    case .range(let start, let end):
      let startText = start?.formatted(date: .abbreviated, time: .omitted) ?? "Start"
      let endText = end?.formatted(date: .abbreviated, time: .omitted) ?? "End"
      return "Range: \(startText) to \(endText)"
    case .multiple(let dates):
      return "\(dates.count) dates selected"
    }
  }
}
