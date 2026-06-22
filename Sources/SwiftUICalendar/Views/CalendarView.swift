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
  private let viewModel: CalendarViewModel
  private let theme: Theme
  private let typography: Typography

  /// Creates a calendar view with the supplied model, theme, and typography.
  ///
  /// Use the default theme for a fixed one-month calendar, or pass a customized theme for
  /// vertical scrolling, horizontal paging, alternate day cells, and color changes.
  ///
  /// - Parameters:
  ///   - model: The calendar view model that drives selection and navigation.
  ///   - theme: Visual configuration for day rendering and behavior.
  ///   - typography: Fonts and scaling settings for calendar text.
  ///
  /// ```swift
  /// let theme = Theme()
  /// theme.scrollMode = .horizontal
  /// theme.day.selectedBackgroundColor = .purple
  ///
  /// CalendarView(
  ///     model: CalendarViewModel(calendarIdentifier: .persian),
  ///     theme: theme,
  ///     typography: .default
  /// )
  /// ```
  public init(
    model: CalendarViewModel,
    theme: Theme = .default,
    typography: Typography = .default
  ) {
    self.viewModel = model
    self.theme = theme
    self.typography = typography
  }

  @ViewBuilder
  private var calendarBodyContent: some View {
    switch theme.scrollMode {
    case .none:
      CalendarBodyView()
    case .vertical:
      CalendarBodyVerticalContainer()
    case .horizontal:
      CalendarBodyHorizontalContainer(viewModel: viewModel)
    }
  }

  /// The SwiftUI body for the calendar view.
  ///
  /// You normally do not call this property directly. SwiftUI evaluates it as part of the
  /// standard `View` lifecycle.
  public var body: some View {
    VStack {
      #if os(iOS)
        HStack {
          Spacer()
          Button("Calendar.Today".localized) {
            viewModel.goToToday()
          }
        }
      #endif
      if viewModel.showHeader {
        CalendarHeaderView()
      }
      calendarBodyContent
        .frame(maxWidth: .infinity, maxHeight: fillsAvailableHeight ? .infinity : nil, alignment: .top)
        .layoutPriority(1)
    }
    .safeAreaPadding(10)
    .environment(viewModel)
    .environment(theme)
    .environment(typography)
    .environment(\.locale, viewModel.locale)
    .environment(\.layoutDirection, viewModel.layoutDirection)
    .resolveCalendarMetrics()
    // Scroll modes own their scrolling and fill the offered height. The fixed single-month layout
    // hugs its content so the host can place it freely (e.g. center it) instead of being pinned.
    .frame(maxWidth: .infinity, maxHeight: fillsAvailableHeight ? .infinity : nil, alignment: .top)
  }

  /// Whether the body should expand to fill the offered height. True for scrolling modes; false for
  /// the fixed single-month layout, which hugs its content.
  private var fillsAvailableHeight: Bool {
    theme.scrollMode != .none
  }
}

#Preview("Calendar Configurations") {
  CalendarPreviewConfigurator()
}

private struct CalendarBodyVerticalContainer: View {
  var body: some View {
    CalendarBodyVerticalView()
  }
}

private struct CalendarBodyHorizontalContainer: View {
  let viewModel: CalendarViewModel

  var body: some View {
    CalendarBodyHorizontalView(viewModel: viewModel)
  }
}

private struct CalendarPreviewContainer: View {
  @State private var calendarIdentifier: Calendar.Identifier = .gregorian
  let title: String
  let scrollMode: Theme.ScrollMode
  let selection: CalendarViewModel.Selection
  var themeConfigurator: ((Theme) -> Void)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
      Picker("Calendar", selection: $calendarIdentifier) {
        Text("Gregorian").tag(Calendar.Identifier.gregorian)
        Text("Persian").tag(Calendar.Identifier.persian)
      }
      .pickerStyle(.segmented)
      CalendarView(
        model: CalendarViewModel(calendarIdentifier: calendarIdentifier, selection: selection),
        theme: configuredTheme(),
        typography: .default
      )
      .frame(height: 520, alignment: .top)
      .id("\(String(describing: calendarIdentifier))-\(String(describing: scrollMode))")
    }
    .padding()
  }

  private func configuredTheme() -> Theme {
    let theme = Theme()
    theme.scrollMode = scrollMode
    themeConfigurator?(theme)
    return theme
  }
}

private struct CalendarPreviewConfigurator: View {
  @State private var calendarIdentifier: Calendar.Identifier = .gregorian
  @State private var selectionMode: PreviewSelectionMode = .single
  @State private var scrollMode: Theme.ScrollMode = .none
  @State private var dayMode: PreviewDayMode = .circle
  @State private var previewModel = CalendarViewModel(
    calendarIdentifier: .gregorian, selection: .single(Date()))

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Calendar Preview")
        .font(.headline)
      Picker("Calendar", selection: $calendarIdentifier) {
        Text("Gregorian").tag(Calendar.Identifier.gregorian)
        Text("Persian").tag(Calendar.Identifier.persian)
      }
      .pickerStyle(.segmented)
      Picker("Selection", selection: $selectionMode) {
        ForEach(PreviewSelectionMode.allCases) { mode in
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
      Picker("Day View", selection: $dayMode) {
        ForEach(PreviewDayMode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      previewCalendar
        .id(previewId)
    }
    .padding()
    .onAppear {
      applyPreviewConfiguration()
    }
    .onChange(of: calendarIdentifier) { _, _ in
      applyPreviewConfiguration()
    }
    .onChange(of: selectionMode) { _, _ in
      applyPreviewConfiguration()
    }
    .onChange(of: dayMode) { _, _ in
      applyPreviewConfiguration()
    }
  }

  private var previewId: String {
    "\(String(describing: calendarIdentifier))-\(selectionMode.rawValue)-\(String(describing: scrollMode))"
  }

  private var previewCalendar: some View {
    let calendarView = CalendarView(
      model: previewModel,
      theme: configuredTheme(),
      typography: .default
    )
    switch scrollMode {
    case .vertical:
      return AnyView(calendarView.frame(height: 520, alignment: .top))
    case .horizontal, .none:
      return AnyView(calendarView.fixedSize(horizontal: false, vertical: true))
    }
  }

  private func configuredTheme() -> Theme {
    let theme = Theme()
    theme.scrollMode = scrollMode
    dayMode.apply(to: theme)
    // Keep this in previews to demonstrate alternate calendar labeling.
    theme.day.secondaryLabelMode = .persian
    return theme
  }

  private func applyPreviewConfiguration() {
    previewModel.updateCalendar(identifier: calendarIdentifier)
    previewModel.currentDate = Date()
    previewModel.selection = selectionMode.selectionValue(baseDate: Date())
  }
}

private enum PreviewSelectionMode: String, CaseIterable, Identifiable {
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
    let next = Calendar.current.date(byAdding: .day, value: 3, to: baseDate) ?? baseDate
    let later = Calendar.current.date(byAdding: .day, value: 10, to: baseDate) ?? baseDate
    switch self {
    case .single:
      return .single(baseDate)
    case .range:
      return .range(baseDate, next)
    case .multiple:
      return .multiple([baseDate, next, later])
    }
  }
}

private enum PreviewDayMode: String, CaseIterable, Identifiable {
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

  @MainActor
  func apply(to theme: Theme) {
    switch self {
    case .circle:
      break
    case .square:
      theme.day.useSquareDualCalendarDayView()
    }
  }
}
