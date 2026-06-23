import SwiftUI
import SwiftUICalendar

struct ContentView: View {
  @State private var calendarIdentifier: Calendar.Identifier = .gregorian
  @State private var selectionMode: SelectionMode = .single
  @State private var scrollMode: Theme.ScrollMode = .none
  @State private var dayViewMode: DayViewMode = .circle
  @State private var horizontalHeightMode: Theme.HorizontalHeightMode = .sixRows
  @State private var viewModel = CalendarViewModel(
    calendarIdentifier: .gregorian, selection: .single(Date()))
  @State private var theme = Theme()
  @State private var typography = Typography.default

  var body: some View {
    VStack(alignment: .center, spacing: 16) {
      GroupBox("Settings") {
        VStack(alignment: .leading, spacing: 12) {
          Picker("Calendar", selection: $calendarIdentifier) {
            Text("Gregorian").tag(Calendar.Identifier.gregorian)
            Text("Persian").tag(Calendar.Identifier.persian)
          }
          .pickerStyle(.segmented)

          Picker("Selection", selection: $selectionMode) {
            ForEach(SelectionMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.segmented)

          Picker("Scroll", selection: $scrollMode) {
            Text("None").tag(Theme.ScrollMode.none)
            Text("Vertical").tag(Theme.ScrollMode.vertical)
            Text("Horizontal").tag(Theme.ScrollMode.horizontal)
          }
          .pickerStyle(.segmented)

          if scrollMode == .horizontal {
            Picker("Horizontal Height", selection: $horizontalHeightMode) {
              Text("Hug Content").tag(Theme.HorizontalHeightMode.hugContent)
              Text("Six Rows").tag(Theme.HorizontalHeightMode.sixRows)
            }
            .pickerStyle(.segmented)
          }

          Picker("Day View", selection: $dayViewMode) {
            ForEach(DayViewMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.segmented)
        }
        .padding(.top, 4)
      }

      CalendarView(model: viewModel, theme: theme, typography: typography)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .id("\(scrollMode)-\(dayViewMode)-\(calendarIdentifier)")
    }
    .padding()
    .onAppear {
      applyConfiguration()
    }
    .onChange(of: calendarIdentifier) { _, _ in
      applyConfiguration()
    }
    .onChange(of: selectionMode) { _, _ in
      applyConfiguration()
    }
    .onChange(of: scrollMode) { _, _ in
      applyConfiguration()
    }
    .onChange(of: dayViewMode) { _, _ in
      applyConfiguration()
    }
    .onChange(of: horizontalHeightMode) { _, _ in
      applyConfiguration()
    }
  }

  private func applyConfiguration() {
    viewModel.updateCalendar(identifier: calendarIdentifier)
    viewModel.currentDate = Date()
    viewModel.selection = selectionMode.selectionValue(baseDate: Date())

    theme.scrollMode = scrollMode
    theme.horizontalHeightMode = horizontalHeightMode

    // Reset day configuration
    theme.day = Theme.Day()

    switch dayViewMode {
    case .circle:
      // For circle mode, only show Persian secondary label when using Persian calendar
      if calendarIdentifier == .persian {
        theme.day.secondaryLabelMode = .persian
      } else {
        theme.day.secondaryLabelMode = .none
      }
    case .square:
      // For square mode, show secondary label based on calendar
      if calendarIdentifier == .persian {
        theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
      } else {
        // For Gregorian calendar, show abbreviated month as secondary label
        theme.day.useSquareDualCalendarDayView(
          secondaryLabel: .custom { date in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
          })
      }
    }
  }
}

private enum SelectionMode: String, CaseIterable, Identifiable {
  case single
  case range
  case multiple

  var id: String { rawValue }

  var title: String {
    switch self {
    case .single:
      "Single"
    case .range:
      "Range"
    case .multiple:
      "Multiple"
    }
  }

  func selectionValue(baseDate: Date) -> CalendarViewModel.Selection {
    _ = Calendar.current.date(byAdding: .day, value: 3, to: baseDate) ?? baseDate
    _ = Calendar.current.date(byAdding: .day, value: 10, to: baseDate) ?? baseDate
    switch self {
    case .single:
      return .single(nil)
    case .range:
      return .range(nil, nil)
    case .multiple:
      return .multiple([])
    }
  }
}

private enum DayViewMode: String, CaseIterable, Identifiable {
  case circle
  case square

  var id: String { rawValue }

  var title: String {
    switch self {
    case .circle:
      "Circle"
    case .square:
      "Square"
    }
  }
}

#Preview {
  ContentView()
}
