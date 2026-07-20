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
  @State private var widthClass: Int = 0

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
        CalendarTodayControl(viewModel: viewModel)
          .frame(height: 28)
      #endif
      if configuration.showsHeader {
        CalendarHeaderControl()
        .frame(height: 44)
      }
      calendarBodyContent
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .layoutPriority(1)
        .onGeometryChange(for: Int.self) { Int($0.size.width / 100) } action: { newClass in
          widthClass = newClass
        }
        // Every calendar body mode (`.none`, `.vertical`, `.horizontal`) resolves its own day
        // grid from a container width that some of them cache in @State (e.g. `CalendarBodyView`
        // measures itself via `.onGeometryChange` when not driven by a parent pager). That cached
        // width can persist from the previous orientation for one render, producing a grid sized
        // for the old width and centered/clipped inside the new, differently-sized viewport.
        // Resetting identity when the width crosses a coarse threshold (which any orientation
        // change does) forces a full re-measurement from scratch instead of reusing stale state.
        .id(widthClass)
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
  var body: some View {
    CalendarBodyVerticalView()
  }
}

private struct CalendarBodyHorizontalContainer: View {
  let viewModel: CalendarViewModel
  @State private var scrollPosition = ScrollPosition(edge: .top)

  var body: some View {
    // A six-row month can exceed a short landscape viewport. Keep the pager horizontally
    // interactive while allowing its rows to overflow vertically instead of compressing.
    // Note: the enclosing `calendarBodyContent` in `CalendarView` already resets this entire
    // subtree's identity (and thus this @State) on orientation change, so `scrollPosition`
    // starts fresh at `.top` for every new orientation without needing its own tracking here.
    ScrollView(.vertical) {
      CalendarBodyHorizontalView(viewModel: viewModel)
        .frame(maxWidth: .infinity, alignment: .top)
    }
    .scrollPosition($scrollPosition)
  }
}
