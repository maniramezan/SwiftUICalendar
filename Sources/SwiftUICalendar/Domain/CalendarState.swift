import Foundation
import SwiftCommons

/// Value state shared by MVVM and externally owned calendars.
public struct CalendarState: Equatable, Sendable {
  public private(set) var calendar: Calendar
  public private(set) var currentDate: Date
  public private(set) var selection: CalendarSelection
  var engine: CalendarEngine { CalendarEngine(calendar: calendar) }
  public var visibleMonth: MonthIdentifier { engine.month(containing: currentDate) }
  var minYear: Int { engine.yearBounds(containing: currentDate).lowerBound }
  var maxYear: Int { engine.yearBounds(containing: currentDate).upperBound }
  var currentMonth: Int { calendar.component(.month, from: currentDate) }

  /// Creates state. An unsupported visible date throws instead of silently clamping.
  public init(
    calendarIdentifier: Calendar.Identifier = .gregorian,
    currentDate: Date = Date(), selection: CalendarSelection = .single(nil)
  ) throws {
    var calendar = Calendar(identifier: calendarIdentifier)
    calendar.locale = Self.locale(for: calendarIdentifier)
    try self.init(calendar: calendar, currentDate: currentDate, selection: selection)
  }

  /// Creates state with an explicit locale and time zone from the supplied calendar.
  public init(calendar: Calendar, currentDate: Date, selection: CalendarSelection = .single(nil))
    throws
  {
    guard CalendarEngine(calendar: calendar).contains(currentDate) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    self.calendar = calendar
    self.currentDate = currentDate
    self.selection = selection.normalized(in: calendar)
  }

  init(calendar: Calendar, clamping date: Date, selection: CalendarSelection) {
    let supported = CalendarEngine(calendar: calendar).supportedDates
    self.calendar = calendar
    self.currentDate = min(
      max(date, supported.lowerBound), supported.upperBound.addingTimeInterval(-1))
    self.selection = selection.normalized(in: calendar)
  }

  /// Applies an interaction atomically. A rejected action leaves state unchanged.
  /// Supply `now` for deterministic handling of the Today action.
  public mutating func apply(_ action: CalendarAction, now: Date = Date()) throws {
    var next = self
    try next.reduce(action, now: now)
    self = next
  }

  private mutating func reduce(_ action: CalendarAction, now: Date) throws {
    switch action {
    case .navigate(let date): try navigate(to: date)
    case .navigateMonth(let month): try navigate(toMonth: month)
    case .navigateVisibleEraMonth(let month): try navigateInVisibleEra(toMonth: month)
    case .navigateComponents(let month, let year): try navigate(toMonth: month, year: year)
    case .navigateYear(let year): try navigate(toYear: year)
    case .offsetMonths(let offset): try updateMonth(byAdding: offset)
    case .offsetYears(let offset):
      guard let date = relativeYearDate(offset) else {
        throw Calendar.CalendarError.cannotCalculateDate
      }
      try navigate(to: date)
    case .select(let date, let navigate):
      if navigate { try self.navigate(to: date) }
      selection = selection.selecting(date, in: calendar)
    case .setSelection(let value): selection = value.normalized(in: calendar)
    case .setCalendar(let identifier):
      var updated = Calendar(identifier: identifier)
      updated.timeZone = calendar.timeZone
      updated.locale = Self.locale(for: identifier)
      calendar = updated
    case .today:
      try navigate(to: now)
      if case .single = selection { selection = .single(calendar.startOfDay(for: now)) }
    }
  }

  private mutating func navigate(to date: Date) throws {
    guard engine.contains(date) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    currentDate = date
  }

  private mutating func navigate(toMonth month: Int, year: Int) throws {
    guard
      let identifier = engine.months(in: year, relativeTo: currentDate).first(where: {
        $0.month == month && $0.isLeapMonth == false
      })
    else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    try navigateInVisibleEra(toMonth: identifier)
  }

  private mutating func navigate(toMonth month: MonthIdentifier) throws {
    guard
      let date = engine.navigationDate(
        in: month, preferredDay: calendar.component(.day, from: currentDate))
    else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    try navigate(to: date)
  }

  private mutating func navigate(toYear year: Int) throws {
    let months = engine.months(in: year, relativeTo: currentDate)
    guard (minYear...maxYear).contains(year),
      let month = months.first(where: {
        $0.month == currentMonth && $0.isLeapMonth == visibleMonth.isLeapMonth
      })
        ?? months.first(where: { $0.month == currentMonth })
        ?? months.last(where: { $0.month < currentMonth }) ?? months.first
    else { throw Calendar.CalendarError.cannotCalculateDate }
    try navigateInVisibleEra(toMonth: month)
  }

  private mutating func navigateInVisibleEra(toMonth month: MonthIdentifier) throws {
    guard
      let date = engine.navigationDate(
        in: month, preferredDay: calendar.component(.day, from: currentDate)),
      let monthInterval = engine.interval(of: month)
    else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    let era = calendar.dateInterval(of: .era, for: currentDate)
    let start = max(monthInterval.start, era?.start ?? monthInterval.start)
    let end = min(monthInterval.end, era?.end ?? monthInterval.end)
    guard start < end else { throw Calendar.CalendarError.cannotCalculateDate }
    try navigate(to: min(max(date, start), end.addingTimeInterval(-1)))
  }

  private mutating func updateMonth(byAdding months: Int) throws {
    guard months != 0 else { return }
    guard let month = engine.month(offset: months, from: visibleMonth) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    try navigate(toMonth: month)
  }

  func relativeYearDate(_ offset: Int) -> Date? {
    guard let date = calendar.date(byAdding: .year, value: offset, to: currentDate),
      let interval = calendar.dateInterval(of: .year, for: date),
      engine.intersectsSupportedDates(interval)
    else { return nil }
    return min(
      max(date, engine.supportedDates.lowerBound),
      engine.supportedDates.upperBound.addingTimeInterval(-1))
  }

  static func locale(for identifier: Calendar.Identifier) -> Locale {
    switch identifier {
    case .buddhist:
      return Locale(identifier: "th_TH@calendar=buddhist")
    case .hebrew:
      return Locale(identifier: "he_IL@calendar=hebrew")
    case .islamic:
      return Locale(identifier: "ar_SA@calendar=islamic")
        .withNumberingSystemIdentifier(.arab)
    case .islamicCivil:
      return Locale(identifier: "ar_SA@calendar=islamic-civil")
        .withNumberingSystemIdentifier(.arab)
    case .islamicTabular:
      return Locale(identifier: "ar_SA@calendar=islamic-tbla")
        .withNumberingSystemIdentifier(.arab)
    case .islamicUmmAlQura:
      return Locale(identifier: "ar_SA@calendar=islamic-umalqura")
        .withNumberingSystemIdentifier(.arab)
    case .japanese:
      return Locale(identifier: "ja_JP@calendar=japanese")
    case .persian:
      return Locale(identifier: "fa_IR@calendar=persian")
        .withNumberingSystemIdentifier(.arabExtended)
    default:
      return Locale(calendarIdentifier: identifier)
    }
  }
}
