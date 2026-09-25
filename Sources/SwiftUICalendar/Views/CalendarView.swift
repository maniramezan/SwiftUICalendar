import OSLog
import SwiftCommons
import SwiftUI

/// A configurable SwiftUI calendar view with calendar-system aware layout, selection, and theming.
///
/// `CalendarView` is the package entry point. Create a `CalendarViewModel`, optionally customize
/// `Theme` and `Typography`, then embed the view anywhere SwiftUI content is accepted.
///
/// ```swift
/// struct BookingScreen: View {
///     @State private var calendar = CalendarViewModel(
///         calendarIdentifier: .gregorian,
///         selection: .range(nil, nil)
///     )
///
///     var body: some View {
///         CalendarView(model: calendar)
///             .frame(minHeight: 420)
///     }
/// }
/// ```
public struct CalendarView: View {
    private enum Source {
        case owned(CalendarViewModel)
        case external(state: CalendarState, onAction: (CalendarAction) -> Void)
    }

    private let source: Source
    private let theme: Theme
    private let typography: Typography
    private let configuration: CalendarConfiguration
    // Persists the projection built for `.external` across re-renders (e.g. every TCA store
    // mutation) instead of the `init(state:onAction:)` below constructing a fresh one each time.
    // See `CalendarViewModel.sync(state:onAction:)` for why replacing the instance every render
    // would defeat `@Observable`'s per-property diffing for every downstream view.
    @State private var externalViewModel: CalendarViewModel?
    @State private var keyboard = CalendarKeyboardCursor()
    @FocusState private var isKeyboardFocused: Bool
    private let logger = Logger.swiftUICalendar(for: CalendarView.self)

    private var viewModel: CalendarViewModel {
        switch source {
        case .owned(let model):
            return model
        case .external(let state, let onAction):
            guard let externalViewModel else {
                // Unreachable in practice: `init(state:onAction:)` always seeds `externalViewModel`
                // via `State(initialValue:)` alongside `.external`. Falling back defensively rather
                // than force-unwrapping.
                return CalendarViewModel(state: state, onAction: onAction)
            }
            externalViewModel.sync(state: state, onAction: onAction)
            return externalViewModel
        }
    }

    /// Creates a calendar view with the supplied model, theme, and typography.
    ///
    /// Use the default theme for a fixed one-month calendar, or pass a customized theme for
    /// alternate day cells and color changes. Pass a configuration for presentation behavior.
    ///
    /// - Parameters:
    ///   - model: The calendar view model that drives selection and navigation.
    ///   - theme: Visual configuration for day rendering and behavior.
    ///   - typography: Fonts and scaling settings for calendar text.
    ///   - configuration: Immutable scrolling, header, and year-selection behavior.
    ///
    /// ```swift
    /// let theme = Theme()
    /// let configuration = CalendarConfiguration(scrollMode: .horizontal)
    /// theme.day.selectedBackgroundColor = .purple
    ///
    /// CalendarView(
    ///     model: CalendarViewModel(calendarIdentifier: .persian),
    ///     theme: theme,
    ///     typography: .default,
    ///     configuration: configuration
    /// )
    /// ```
    public init(
        model: CalendarViewModel,
        theme: Theme = .default,
        typography: Typography = .default,
        configuration: CalendarConfiguration = CalendarConfiguration()
    ) {
        self.source = .owned(model)
        self.theme = theme
        self.typography = typography
        self.configuration = configuration
    }

    /// Renders externally owned state and forwards interactions to its owner.
    /// The view never changes this state or maintains a synchronized mutable copy.
    public init(
        state: CalendarState,
        theme: Theme = .default,
        typography: Typography = .default,
        configuration: CalendarConfiguration = CalendarConfiguration(),
        onAction: @escaping (CalendarAction) -> Void
    ) {
        self.source = .external(state: state, onAction: onAction)
        self.theme = theme
        self.typography = typography
        self.configuration = configuration
        self._externalViewModel = State(
            initialValue: CalendarViewModel(state: state, onAction: onAction))
    }

    @ViewBuilder
    private func calendarBodyContent(allowsPaging: Bool) -> some View {
        switch configuration.scrollMode {
        case .none:
            CalendarBodyView(keyboard: keyboard)
        case .vertical:
            CalendarBodyVerticalContainer(keyboard: keyboard)
        case .horizontal:
            CalendarBodyHorizontalContainer(
                viewModel: viewModel, allowsPaging: allowsPaging, keyboard: keyboard)
        }
    }

    /// The SwiftUI body for the calendar view.
    ///
    /// You normally do not call this property directly. SwiftUI evaluates it as part of the
    /// standard `View` lifecycle.
    public var body: some View {
        CalendarViewport(keyboard: keyboard) { allowsPaging in
            VStack {
                #if os(iOS)
                    CalendarTodayControl(viewModel: viewModel)
                        .frame(height: 28)
                #endif
                if configuration.showsHeader {
                    CalendarHeaderControl()
                        .frame(height: 44)
                }
                calendarBodyContent(allowsPaging: allowsPaging)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .layoutPriority(1)

            }
        }
        // Not focusable at all when the host declined every shortcut, so the calendar stops
        // being a tab stop it would do nothing with.
        .focusable(!configuration.keyboardNavigation.isEmpty, interactions: .edit)
        .focused($isKeyboardFocused)
        .onChange(of: isKeyboardFocused) { _, focused in
            logger.debug("Keyboard focus \(focused ? "gained" : "lost", privacy: .public)")
            keyboard.isActive = focused
            if focused {
                if let tapped = keyboard.takePendingFocusDate() {
                    keyboard.date = tapped
                } else {
                    keyboard.follow(viewModel.currentDate, calendar: viewModel.engine.calendar)
                }
            }
        }
        .onChange(of: keyboard.focusRequest) { _, _ in
            guard !configuration.keyboardNavigation.isEmpty else { return }
            logger.debug("Keyboard focus requested by a tapped day")
            if isKeyboardFocused, let tapped = keyboard.takePendingFocusDate() {
                keyboard.date = tapped
            } else {
                isKeyboardFocused = true
            }
        }
        .onChange(of: viewModel.currentDate) { _, date in
            // `follow`, not a scroll request: this also fires when a settled scroll navigates the
            // model, and asking the scroll container to move would fight the user's own gesture.
            guard keyboard.isActive else { return }
            keyboard.follow(date, calendar: viewModel.engine.calendar)
        }
        .onKeyPress(phases: [.down, .repeat]) { press in
            keyboard.hasSeenKeyInput = true
            let result = handleKeyPress(press)
            // Key codes, not characters: the log never carries text a person typed.
            let key = press.key.character.unicodeScalars
                .map { String($0.value, radix: 16) }.joined()
            let outcome = result == .handled ? "handled" : "ignored"
            logger.debug(
                "Key \(key, privacy: .public) modifiers \(press.modifiers.rawValue) → \(outcome, privacy: .public)"
            )
            return result
        }
        .environment(viewModel)
        .environment(theme)
        .environment(typography)
        .environment(\.calendarConfiguration, configuration)
        .environment(\.locale, viewModel.locale)
        .environment(\.layoutDirection, viewModel.layoutDirection)
        .resolveCalendarMetrics()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Keyboard Input

    /// Routes a key press to the cursor, consuming it only when the calendar acted on it.
    ///
    /// A refused shortcut returns `.ignored` rather than `.handled`: swallowing `⌘T` at the edge of
    /// the date range, or an arrow key at the first available day, would stop the host app and the
    /// system from seeing a key the calendar did nothing with.
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let shortcuts = configuration.keyboardNavigation
        guard isKeyboardFocused, !shortcuts.isEmpty else { return .ignored }
        let modifiers = CalendarKeyboardCursor.meaningfulModifiers(press.modifiers)
        do {
            if shortcuts.contains(.arrows), modifiers.isEmpty,
                let days = CalendarKeyboardCursor.dayOffset(
                    for: press.key, direction: viewModel.layoutDirection)
            {
                return try keyboard.move(days: days, model: viewModel) ? .handled : .ignored
            }
            if shortcuts.contains(.arrows), modifiers.isEmpty,
                press.key == .return || press.key == .space
            {
                // Selection fires once per physical press; a held key must not re-select.
                guard press.phase == .down else { return .handled }
                return keyboard.select(model: viewModel) ? .handled : .ignored
            }
            if shortcuts.contains(.today), modifiers == .command, press.key == "t" {
                return keyboard.goToToday(model: viewModel) ? .handled : .ignored
            }
            if shortcuts.contains(.monthShortcuts), modifiers == .command,
                let months = CalendarKeyboardCursor.monthOffset(
                    for: press.key, direction: viewModel.layoutDirection)
            {
                return try keyboard.moveMonths(months, model: viewModel) ? .handled : .ignored
            }
        } catch {
            logger.error(
                "Keyboard navigation failed", error: error, context: "calendar keyboard navigation")
            return .ignored
        }
        return .ignored
    }
}

private struct CalendarHeaderControl: View {
    @Environment(\.calendarConfiguration) private var configuration
    @Environment(\.calendarMetrics) private var metrics

    var body: some View {
        GeometryReader { geometry in
            CalendarHeaderView()
                .frame(
                    width: CalendarGridLayout(
                        containerWidth: geometry.size.width,
                        metrics: metrics,
                        sizing: configuration.gridSizing
                    ).gridWidth
                )
                .frame(maxWidth: .infinity)
        }
    }
}

#if os(iOS)
    private struct CalendarTodayControl: View {
        @Environment(\.calendarConfiguration) private var configuration
        @Environment(\.calendarMetrics) private var metrics
        let viewModel: CalendarViewModel

        var body: some View {
            GeometryReader { geometry in
                HStack {
                    Spacer()
                    Button("Calendar.Today".localized) {
                        viewModel.goToToday()
                    }
                    // Today can fall outside `dateRange` (for example, a past-only calendar).
                    .disabled(!viewModel.canGoToToday)
                }
                .frame(
                    width: CalendarGridLayout(
                        containerWidth: geometry.size.width,
                        metrics: metrics,
                        sizing: configuration.gridSizing
                    ).gridWidth,
                    alignment: .trailing
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
#endif

#Preview("Calendar") {
    CalendarView(model: .test(identifier: .persian))
        .frame(height: 520)
}

private struct CalendarBodyVerticalContainer: View {
    let keyboard: CalendarKeyboardCursor

    var body: some View {
        CalendarBodyVerticalView(keyboard: keyboard)
    }
}

private struct CalendarBodyHorizontalContainer: View {
    let viewModel: CalendarViewModel
    let allowsPaging: Bool
    let keyboard: CalendarKeyboardCursor
    @State private var scrollPosition = ScrollPosition(edge: .top)

    var body: some View {
        // A six-row month can exceed a short landscape viewport. Keep the pager horizontally
        // interactive while allowing its rows to overflow vertically instead of compressing.
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                CalendarBodyHorizontalView(
                    viewModel: viewModel, allowsPaging: allowsPaging, keyboard: keyboard
                )
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollPosition($scrollPosition)
            // `scrollRequest`, not `date`: swiping to another month or tapping Today moves the
            // cursor to follow, and scrolling on that would move this list with no key pressed.
            .onChange(of: keyboard.scrollRequest) { _, request in
                guard keyboard.isActive, let request else { return }
                proxy.scrollTo(request.identity)
            }
        }
    }
}
