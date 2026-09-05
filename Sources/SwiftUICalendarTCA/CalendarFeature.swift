#if TCA
  import ComposableArchitecture
  import Foundation
  import SwiftUICalendar

  /// Reducer that owns the calendar's value state and uses the core domain transitions.
  @Reducer
  public struct CalendarFeature {
    @ObservableState
    public struct State: Equatable, Sendable {
      public var calendar: CalendarState
      public init(calendar: CalendarState) { self.calendar = calendar }
    }

    public enum Action: Equatable, Sendable {
      case view(CalendarAction)
      case delegate(DelegateAction)

      public enum DelegateAction: Equatable, Sendable {
        case selectionChanged(CalendarSelection)
        case navigationRejected(CalendarAction)
      }
    }

    @Dependency(\.date.now) var now

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let intent):
          let previousSelection = state.calendar.selection
          do {
            // Only Today reads the clock; other transitions are pure.
            try state.calendar.apply(
              intent, now: intent == .today ? now : state.calendar.currentDate)
          } catch {
            return .send(.delegate(.navigationRejected(intent)))
          }
          if state.calendar.selection != previousSelection {
            return .send(.delegate(.selectionChanged(state.calendar.selection)))
          }
          return .none
        case .delegate:
          return .none
        }
      }
    }
  }
#endif
