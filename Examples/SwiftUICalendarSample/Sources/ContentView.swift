import ComposableArchitecture
import SwiftUI
import SwiftUICalendar
import SwiftUICalendarAccessibility
import SwiftUICalendarTCA

struct ContentView: View {
    @State private var calendarIdentifier: Calendar.Identifier = .gregorian
    @State private var selectionMode: SampleSelectionMode = .single
    @State private var scrollMode: CalendarConfiguration.ScrollMode = .none
    @State private var dayViewMode: SampleDayViewMode = .circle
    @State private var horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode = .sixRows
    @State private var architecture: SampleArchitecture = .mvvm
    @State private var viewModel = CalendarViewModel(
        calendarIdentifier: .gregorian, selection: .single(nil))
    @State private var tcaStore: StoreOf<CalendarFeature>?
    @State private var theme = Theme()
    @State private var typography = Typography.default
    @State private var isSettingsPresented = false

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
            // Launch-only fixture for validating the calendar inside an inset host.
            .padding(
                .horizontal, max(0, UserDefaults.standard.double(forKey: "calendar-host-inset"))
            )
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    Spacer()
                    // A toggle: in regular width the inspector sits beside the calendar, and the
                    // same button is how it closes.
                    Button {
                        isSettingsPresented.toggle()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Choose calendar display settings")
                    .accessibilityIdentifier(CalendarSampleAccessibilityID.settings)
                }
                .padding(.horizontal)
            }
            .modifier(
                SettingsPresentation(
                    isPresented: $isSettingsPresented,
                    // Keep the presentation kind stable when a phone rotates to regular width.
                    usesSheet: UIDevice.current.userInterfaceIdiom == .phone
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
        let selection = selectionMode.selectionValue
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
        let selection = selectionMode.selectionValue
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
        if usesSheet {
            // Do not install an inactive inspector on phones. Its compact adaptation can
            // re-present stale content during rotation even with a constant false binding.
            content.sheet(isPresented: $isPresented) {
                settings(true)
            }
        } else {
            content.inspector(isPresented: $isPresented) {
                // An iPad inspector can adapt to a sheet in narrow multitasking widths.
                settings(true)
                    .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
            }
        }
    }
}

private struct ConfigurationView: View {
    @Binding var architecture: SampleArchitecture
    @Binding var calendarIdentifier: Calendar.Identifier
    @Binding var selectionMode: SampleSelectionMode
    @Binding var scrollMode: CalendarConfiguration.ScrollMode
    @Binding var horizontalHeightMode: CalendarConfiguration.HorizontalHeightMode
    @Binding var dayViewMode: SampleDayViewMode
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
                                .accessibilityIdentifier(path.accessibilityIdentifier)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(CalendarSampleAccessibilityID.stateOwnerPicker)
                }

                Section("Calendar") {
                    Picker("Calendar", selection: $calendarIdentifier) {
                        Text("Gregorian").tag(Calendar.Identifier.gregorian)
                            .accessibilityIdentifier(
                                CalendarSampleAccessibilityID.calendarOption(.gregorian))
                        Text("Persian").tag(Calendar.Identifier.persian)
                            .accessibilityIdentifier(
                                CalendarSampleAccessibilityID.calendarOption(.persian))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(CalendarSampleAccessibilityID.calendarPicker)

                    Picker("Selection", selection: $selectionMode) {
                        ForEach(SampleSelectionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                                .accessibilityIdentifier(mode.accessibilityIdentifier)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(CalendarSampleAccessibilityID.selectionPicker)
                }

                Section("Layout") {
                    Picker("Scroll", selection: $scrollMode) {
                        Text("None").tag(CalendarConfiguration.ScrollMode.none)
                            .accessibilityIdentifier(
                                CalendarScrollMode.none.accessibilityIdentifier)
                        Text("Vertical").tag(CalendarConfiguration.ScrollMode.vertical)
                            .accessibilityIdentifier(
                                CalendarScrollMode.vertical.accessibilityIdentifier)
                        Text("Horizontal").tag(CalendarConfiguration.ScrollMode.horizontal)
                            .accessibilityIdentifier(
                                CalendarScrollMode.horizontal.accessibilityIdentifier)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(CalendarSampleAccessibilityID.scrollModePicker)

                    if scrollMode == .horizontal {
                        Picker("Horizontal Height", selection: $horizontalHeightMode) {
                            ForEach(CalendarHorizontalHeightMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                                    .accessibilityIdentifier(mode.accessibilityIdentifier)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier(
                            CalendarSampleAccessibilityID.horizontalHeightPicker)
                    }

                    Picker("Day View", selection: $dayViewMode) {
                        ForEach(SampleDayViewMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                                .accessibilityIdentifier(mode.accessibilityIdentifier)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier(CalendarSampleAccessibilityID.dayViewPicker)
                }
            }
            .navigationTitle("Settings")
            .safeAreaInset(edge: .top, spacing: 0) {
                // Keep dismissal inside the presentation instead of merging an inspector toolbar
                // into the calendar's navigation bar, where it can linger after dismissal.
                if showsDone {
                    HStack {
                        Spacer()
                        Button {
                            isPresented = false
                        } label: {
                            Text("Done")
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(CalendarSampleAccessibilityID.done)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

/// The library's selection types stay in the sample, where the model is available to build them.
extension SampleSelectionMode {
    var selectionValue: CalendarViewModel.Selection {
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

extension CalendarHorizontalHeightMode {
    var title: String {
        switch self {
        case .hugContent:
            return "Hug Content"
        case .sixRows:
            return "Six Rows"
        }
    }
}

#Preview {
    ContentView()
}
