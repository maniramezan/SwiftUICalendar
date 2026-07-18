import SwiftUI
import SwiftUICalendar

struct ContentView: View {
  @State private var calendarIdentifier: Calendar.Identifier = .gregorian
  @State private var selectionMode: SelectionMode = .single
  @State private var scrollMode: CalendarConfiguration.ScrollMode = .none
  @State private var dayViewMode: DayViewMode = .circle
  @State private var horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode = .sixRows
  @State private var viewModel = CalendarViewModel(
    calendarIdentifier: .gregorian, selection: .single(Date()))
  @State private var theme = Theme()
  @State private var typography = Typography.default
  @State private var isSettingsPresented = false

  var body: some View {
    NavigationStack {
      SampleCalendarContent(
        viewModel: viewModel,
        theme: theme,
        typography: typography,
        scrollMode: scrollMode,
        horizontalHeightMode: horizontalHeightMode
      )
      .navigationTitle("Calendar")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button("Settings", systemImage: "gearshape") {
            isSettingsPresented = true
          }
          .accessibilityHint("Choose calendar display settings")
        }
      }
    }
    .sheet(isPresented: $isSettingsPresented) {
      ConfigurationView(
        calendarIdentifier: $calendarIdentifier,
        selectionMode: $selectionMode,
        scrollMode: $scrollMode,
        horizontalHeightMode: $horizontalHeightMode,
        dayViewMode: $dayViewMode
      )
    }
    .onChange(of: calendarIdentifier) { _, _ in
      applyCalendarIdentifier()
    }
    .onChange(of: selectionMode) { _, _ in
      applySelectionMode()
    }
    .onChange(of: dayViewMode) { _, _ in
      applyDayConfiguration()
    }
  }

  private func applyCalendarIdentifier() {
    viewModel.updateCalendar(identifier: calendarIdentifier)
    applyDayConfiguration()
  }

  private func applySelectionMode() {
    viewModel.selection = selectionMode.selectionValue(baseDate: Date())
  }

  private func applyDayConfiguration() {
    theme.day = Theme.Day()

    switch dayViewMode {
    case .circle:
      if calendarIdentifier == .persian {
        theme.day.secondaryLabelMode = .persian
      }
    case .square:
      if calendarIdentifier == .persian {
        theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)
      } else {
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

private struct SampleCalendarContent: View {
  let viewModel: CalendarViewModel
  let theme: Theme
  let typography: Typography
  let scrollMode: CalendarConfiguration.ScrollMode
  let horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode

  var body: some View {
    Group {
      if scrollMode == .none {
        ScrollView {
          CalendarView(
            model: viewModel,
            theme: theme,
            typography: typography,
            configuration: configuration
          )
        }
      } else {
        CalendarView(
          model: viewModel,
          theme: theme,
          typography: typography,
          configuration: configuration
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private var configuration: CalendarConfiguration {
    CalendarConfiguration(
      scrollMode: scrollMode,
      horizontalHeightMode: horizontalHeightMode
    )
  }
}

private struct ConfigurationView: View {
  @Environment(\.dismiss) private var dismiss

  @Binding var calendarIdentifier: Calendar.Identifier
  @Binding var selectionMode: SelectionMode
  @Binding var scrollMode: CalendarConfiguration.ScrollMode
  @Binding var horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode
  @Binding var dayViewMode: DayViewMode

  var body: some View {
    NavigationStack {
      Form {
        Section("Calendar") {
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
        }

        Section("Layout") {
          Picker("Scroll", selection: $scrollMode) {
            Text("None").tag(CalendarConfiguration.ScrollMode.none)
            Text("Vertical").tag(CalendarConfiguration.ScrollMode.vertical)
            Text("Horizontal").tag(CalendarConfiguration.ScrollMode.horizontal)
          }
          .pickerStyle(.segmented)

          if scrollMode == .horizontal {
            Picker("Horizontal Height", selection: $horizontalHeightMode) {
              Text("Hug Content").tag(CalendarConfiguration.HorizontalHeightMode.hugContent)
              Text("Six Rows").tag(CalendarConfiguration.HorizontalHeightMode.sixRows)
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
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
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
