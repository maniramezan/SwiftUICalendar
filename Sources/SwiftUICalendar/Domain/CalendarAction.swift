import Foundation

/// User intents accepted by both the observable model and an external state owner.
public enum CalendarAction: Equatable, Sendable {
  case navigate(Date)
  case navigateMonth(MonthIdentifier)
  case navigateVisibleEraMonth(MonthIdentifier)
  case navigateComponents(month: Int, year: Int)
  case navigateYear(Int)
  case offsetMonths(Int)
  case offsetYears(Int)
  case select(Date, navigating: Bool = false)
  case setSelection(CalendarSelection)
  case setCalendar(Calendar.Identifier)
  case today
}
