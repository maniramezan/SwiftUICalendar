import ComposableArchitecture
import SwiftUI
import SwiftUICalendar

/// A calendar whose sole state owner is a TCA store.
public struct TCACalendarView: View {
  private let store: StoreOf<CalendarFeature>
  private let theme: Theme
  private let typography: Typography
  private let configuration: CalendarConfiguration

  public init(
    store: StoreOf<CalendarFeature>, theme: Theme = .default,
    typography: Typography = .default,
    configuration: CalendarConfiguration = CalendarConfiguration()
  ) {
    self.store = store
    self.theme = theme
    self.typography = typography
    self.configuration = configuration
  }

  public var body: some View {
    CalendarView(
      state: store.calendar, theme: theme, typography: typography,
      configuration: configuration
    ) { store.send(.view($0)) }
  }
}
