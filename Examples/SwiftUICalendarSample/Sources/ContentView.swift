import ComposableArchitecture
import SwiftUI
import SwiftUICalendar
import SwiftUICalendarTCA

struct ContentView: View {
    @State private var calendarIdentifier: Calendar.Identifier = .gregorian
    @State private var selectionMode: SelectionMode = .single
    @State private var scrollMode: CalendarConfiguration.ScrollMode = .none
    @State private var dayViewMode: DayViewMode = .circle
    @State private var horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode = .sixRows
    @State private var architecture: SampleArchitecture = .mvvm
    @State private var viewModel = CalendarViewModel(
        calendarIdentifier: .gregorian, selection: .single(nil))
    @State private var tcaStore: StoreOf<CalendarFeature>?
    @State private var theme = Theme()
    @State private var typography = Typography.default
    @State private var isSettingsPresented = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            SampleCalendarContent(
                architecture: architecture,
                viewModel: viewModel,
                tcaStore: tcaStore,
                theme: theme,
                typography: typography,
                scrollMode: scrollMode,
                horizontalHeightMode: horizontalHeightMode
            )
            .id(architecture)
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // A toggle: in regular width the inspector sits beside the calendar, and the
                    // same button is how it closes.
                    Button("Settings", systemImage: "gearshape") {
                        isSettingsPresented.toggle()
                    }
                    .accessibilityHint("Choose calendar display settings")
                }
            }
            .modifier(
                SettingsPresentation(
                    isPresented: $isSettingsPresented,
                    usesSheet: horizontalSizeClass == .compact
                ) { showsDone in
                    ConfigurationView(
                        architecture: $architecture,
                        calendarIdentifier: $calendarIdentifier,
                        selectionMode: $selectionMode,
                        scrollMode: $scrollMode,
                        horizontalHeightMode: $horizontalHeightMode,
                        dayViewMode: $dayViewMode,
                        isPresented: $isSettingsPresented,
                        showsDone: showsDone
                    )
                }
            )
        }
        .onChange(of: architecture) { _, _ in
            resettleArchitecture()
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

    // MARK: - Architecture switching

    private func resettleArchitecture() {
        let selection = selectionMode.selectionValue(baseDate: Date())
        switch architecture {
        case .mvvm:
            tcaStore = nil
            viewModel = CalendarViewModel(
                calendarIdentifier: calendarIdentifier, selection: selection)
        case .tca:
            let seed = CalendarViewModel(
                calendarIdentifier: calendarIdentifier, selection: selection)
            tcaStore = StoreOf<CalendarFeature>(
                initialState: CalendarFeature.State(calendar: seed.state),
                reducer: { CalendarFeature() }
            )
        }
    }

    // MARK: - Settings application

    private func applyCalendarIdentifier() {
        switch architecture {
        case .mvvm:
            viewModel.updateCalendar(identifier: calendarIdentifier)
        case .tca:
            tcaStore?.send(.view(.setCalendar(calendarIdentifier)))
        }
        applyDayConfiguration()
    }

    private func applySelectionMode() {
        let selection = selectionMode.selectionValue(baseDate: Date())
        switch architecture {
        case .mvvm:
            viewModel.selection = selection
        case .tca:
            tcaStore?.send(.view(.setSelection(selection)))
        }
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
    let architecture: SampleArchitecture
    let viewModel: CalendarViewModel
    let tcaStore: StoreOf<CalendarFeature>?
    let theme: Theme
    let typography: Typography
    let scrollMode: CalendarConfiguration.ScrollMode
    let horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode

    var body: some View {
        Group {
            if scrollMode == .none {
                ScrollView {
                    SampleCalendarPath(
                        architecture: architecture,
                        viewModel: viewModel,
                        tcaStore: tcaStore,
                        theme: theme,
                        typography: typography,
                        scrollMode: scrollMode,
                        horizontalHeightMode: horizontalHeightMode
                    )
                }
            } else {
                SampleCalendarPath(
                    architecture: architecture,
                    viewModel: viewModel,
                    tcaStore: tcaStore,
                    theme: theme,
                    typography: typography,
                    scrollMode: scrollMode,
                    horizontalHeightMode: horizontalHeightMode
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SampleCalendarPath: View {
    let architecture: SampleArchitecture
    let viewModel: CalendarViewModel
    let tcaStore: StoreOf<CalendarFeature>?
    let theme: Theme
    let typography: Typography
    let scrollMode: CalendarConfiguration.ScrollMode
    let horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode

    private var configuration: CalendarConfiguration {
        CalendarConfiguration(
            scrollMode: scrollMode,
            horizontalHeightMode: horizontalHeightMode
        )
    }

    var body: some View {
        if let tcaStore, architecture == .tca {
            TCACalendarView(
                store: tcaStore,
                theme: theme,
                typography: typography,
                configuration: configuration
            )
        } else {
            CalendarView(
                model: viewModel,
                theme: theme,
                typography: typography,
                configuration: configuration
            )
        }
    }
}

/// Settings beside the calendar in regular width, as a sheet in compact width.
///
/// One `.inspector` covering both failed in two ways. Attached outside the `NavigationStack`, the
/// iPad column stopped opening from the app's second launch on. Attached inside it, the compact
/// sheet lost its navigation bar — title and Done hoisted into the covered calendar's bar — and
/// regular width gained a Done that lingered after close. So each width gets its own presentation.
private struct SettingsPresentation<Settings: View>: ViewModifier {
    @Binding var isPresented: Bool
    let usesSheet: Bool
    @ViewBuilder let settings: (_ showsDone: Bool) -> Settings

    func body(content: Content) -> some View {
        content
            .inspector(isPresented: usesSheet ? .constant(false) : $isPresented) {
                settings(false)
                    .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
            }
            .sheet(isPresented: usesSheet ? $isPresented : .constant(false)) {
                settings(true)
            }
    }
}

private struct ConfigurationView: View {
    @Binding var architecture: SampleArchitecture
    @Binding var calendarIdentifier: Calendar.Identifier
    @Binding var selectionMode: SelectionMode
    @Binding var scrollMode: CalendarConfiguration.ScrollMode
    @Binding var horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode
    @Binding var dayViewMode: DayViewMode
    @Binding var isPresented: Bool
    /// Whether the settings arrive as a sheet, which needs its own way out.
    let showsDone: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Architecture") {
                    Picker("State Owner", selection: $architecture) {
                        ForEach(SampleArchitecture.allCases) { path in
                            Text(path.title).tag(path)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("state-owner-picker")
                }

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
                    .accessibilityIdentifier("scroll-mode-picker")

                    if scrollMode == .horizontal {
                        Picker("Horizontal Height", selection: $horizontalHeightMode) {
                            Text("Hug Content").tag(
                                CalendarConfiguration.HorizontalHeightMode.hugContent)
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
                // Only the compact sheet needs a way out. In regular width the inspector's toolbar
                // merges into the calendar's navigation bar, where a Done would linger after close.
                // The caller decides: inside the inspector the size class does not report compact
                // even when it is presented as a sheet.
                if showsDone {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isPresented = false
                        }
                    }
                }
            }
        }
    }
}

private enum SampleArchitecture: String, CaseIterable, Identifiable {
    case mvvm
    case tca

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mvvm:
            return "MVVM"
        case .tca:
            return "TCA"
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
