import SwiftUI
import SwiftUICalendar

// This consumer intentionally imports the public module without @testable.
@MainActor
struct BookingExample: View {
  @State private var calendar = CalendarViewModel(
    calendarIdentifier: .gregorian, selection: .range(nil, nil))

  var body: some View {
    CalendarView(model: calendar).frame(minHeight: 420)
  }
}

@MainActor
struct EventDayExample: CalendarDayView {
  let context: CalendarDayContext

  init(context: CalendarDayContext) {
    self.context = context
  }

  var body: some View {
    Button {
      context.onSelect(context.date)
    } label: {
      Text(context.dayLabel)
        .font(context.typography.dayFont)
        .frame(minWidth: 44, minHeight: 44)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(context.accessibilityLabel)
    .accessibilityAddTraits(context.isSelected ? .isSelected : [])
  }
}

@MainActor
func configurationExample() throws {
  let calendar = CalendarViewModel(calendarIdentifier: .persian)
  try calendar.navigate(to: Date())
  let month = calendar.visibleMonth
  try calendar.navigate(toMonth: month)
  calendar.selection = .multiple([])
  let theme = Theme()
  theme.day.selectedBackgroundColor = .indigo
  theme.day.setDayContent { EventDayExample(context: $0) }
  let configuration = CalendarConfiguration(
    scrollMode: .horizontal, horizontalHeightMode: .hugContent)
  _ = CalendarView(model: calendar, theme: theme, configuration: configuration)
}

@MainActor
func controlledCalendarExample() throws -> some View {
  let state = try CalendarState(calendarIdentifier: .gregorian)
  return CalendarView(state: state) { action in
    // An owning observable model or reducer applies this action to its state.
    _ = action
  }
}
