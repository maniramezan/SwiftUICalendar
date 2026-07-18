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
  private let configuration: CalendarConfiguration

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
    self.viewModel = model
    self.theme = theme
    self.typography = typography
    self.configuration = configuration
  }

  @ViewBuilder
  private var calendarBodyContent: some View {
    switch configuration.scrollMode {
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
      if configuration.showsHeader {
        CalendarHeaderView()
      }
      calendarBodyContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
    }
    .safeAreaPadding(10)
    .environment(viewModel)
    .environment(theme)
    .environment(typography)
    .environment(\.calendarConfiguration, configuration)
    .environment(\.locale, viewModel.locale)
    .environment(\.layoutDirection, viewModel.layoutDirection)
    .resolveCalendarMetrics()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

#Preview("Calendar") {
  CalendarView(model: .test(identifier: .persian))
    .frame(height: 520)
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
