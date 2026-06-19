import OSLog
import SwiftCommons
import SwiftUI

/// View model that drives calendar layout, selection, and navigation state.
///
/// `CalendarViewModel` owns the current visible date, selected dates, and active calendar system.
/// Store it in SwiftUI state so user interactions update the view and your screen can read the
/// current selection.
///
/// ```swift
/// @State private var calendar = CalendarViewModel(
///     calendarIdentifier: .gregorian,
///     selection: .single(nil)
/// )
///
/// var body: some View {
///     CalendarView(model: calendar)
/// }
/// ```
///
/// The implementation is organized across focused extensions:
/// - `CalendarViewModel+Navigation` — month/year navigation and bounds checks.
/// - `CalendarViewModel+Metadata` — month metadata, grid sizing, and date resolution.
/// - `CalendarViewModel+Selection` — selection state mutation and queries.
@MainActor
@Observable public class CalendarViewModel {

  // MARK: - Selection mode

  /// Selection mode for the calendar.
  ///
  /// The enum value also stores the selected date payload for the active mode. Switching modes
  /// replaces the selection semantics immediately.
  ///
  /// ```swift
  /// let single = CalendarViewModel.Selection.single(Date())
  /// let range = CalendarViewModel.Selection.range(startDate, endDate)
  /// let multiple = CalendarViewModel.Selection.multiple([firstDate, secondDate])
  /// ```
  public enum Selection: Equatable {
    /// A single selected date.
    ///
    /// Tapping the selected date again clears the selection.
    case single(_ date: Date? = nil)
    /// A contiguous range defined by start and end dates.
    ///
    /// The first tap sets the start. The second tap sets the end, automatically sorting the
    /// two dates if the user taps an earlier date second.
    case range(Date? = nil, Date? = nil)
    /// Multiple discrete selected dates.
    ///
    /// Tapping an already selected day removes that date from the set.
    case multiple(Set<Date> = [])
  }

  struct MonthMetadata: Equatable {
    let month: Int
    let year: Int
    let numberOfDays: Int
  }

  // MARK: - Properties

  // MARK: UI Configurations

  /// Controls whether the month and year header controls are shown.
  ///
  /// Set this to `false` when your screen provides its own navigation chrome.
  public var showHeader: Bool = true

  private static let minYear = 1900
  private static let maxYear = 2100

  private(set) var minYear = CalendarViewModel.minYear
  private(set) var maxYear = CalendarViewModel.maxYear

  private let gregorianCalendar = Calendar(identifier: .gregorian)

  let logger = Logger.swiftUICalendar(for: CalendarViewModel.self)

  private(set) var calendar: Calendar {
    didSet {
      updateYearBoundaries()
    }
  }

  var headerTitles: [String] {
    calendar.veryShortWeekdaySymbols
  }

  var locale: Locale {
    calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
  }

  var calendarIdentifier: Calendar.Identifier {
    calendar.identifier
  }

  var calendarSignature: String {
    "\(calendar.identifier)-\(locale.identifier)"
  }

  var startOfMonthDay: Int {
    (try? calendar.startOfMonthDay(for: currentDate)) ?? 1
  }

  var layoutDirection: LayoutDirection {
    // Calendars whose native script is right-to-left (Hebrew, Islamic, Persian) lay out RTL
    // regardless of the system locale's language. This keeps a Hebrew or Islamic calendar
    // mirrored even on an English system, where the resolved locale would otherwise report LTR.
    if calendarIdentifier.prefersRightToLeftLayout {
      return .rightToLeft
    }
    if let languageCode = locale.language.languageCode?.identifier {
      let direction = Locale.Language(identifier: languageCode).characterDirection
      return direction == .rightToLeft ? .rightToLeft : .leftToRight
    }
    return .leftToRight
  }

  var numberOfDaysInMonth: Int {
    (try? calendar.numberOfDays(for: currentDate)) ?? 30
  }

  var currentMonthName: String {
    monthSymbol(for: currentMonth, year: currentYear)
  }

  var currentYear: Int {
    get {
      calendar.year(from: currentDate)
    }
    set {
      guard (minYear...maxYear).contains(newValue),
        let updatedDate = try? calendar.updateYear(newValue, for: currentDate),
        isWithinSupportedYear(updatedDate)
      else {
        return
      }
      currentDate = updatedDate
    }
  }

  var currentMonth: Int {
    get {
      calendar.month(from: currentDate)
    }
    set {
      guard months(in: currentYear).contains(where: { $0.month == newValue }),
        let updatedDate = resolvedDate(
          year: currentYear,
          month: newValue,
          preferredDay: calendar.day(from: currentDate)
        ),
        isWithinSupportedYear(updatedDate)
      else {
        return
      }
      currentDate = updatedDate
    }
  }

  var monthSymbols: [String] {
    calendar.monthSymbols
  }

  /// Current selection state for the calendar.
  ///
  /// Read this value to respond to user selection, or assign a new value to programmatically
  /// change modes or selected dates.
  ///
  /// ```swift
  /// calendar.selection = .multiple([])
  /// ```
  public var selection: Selection

  /// The date representing the currently visible month.
  ///
  /// The day component is preserved when possible during navigation. Assigning a new date moves
  /// the calendar to that date's month in the active calendar system.
  public var currentDate: Date

  /// Creates a view model for a given calendar system and selection mode.
  ///
  /// The initializer configures a locale that matches the selected calendar identifier. Persian
  /// and Islamic calendars use localized numbering systems by default.
  ///
  /// - Parameters:
  ///   - calendarIdentifier: The calendar system to use.
  ///   - selection: Initial selection state.
  ///
  /// ```swift
  /// let gregorian = CalendarViewModel(calendarIdentifier: .gregorian)
  /// let persianRange = CalendarViewModel(
  ///     calendarIdentifier: .persian,
  ///     selection: .range(nil, nil)
  /// )
  /// ```
  public convenience init(
    calendarIdentifier: Calendar.Identifier, selection: Selection = .single(nil)
  ) {
    let locale = Self.locale(for: calendarIdentifier)
    var calendar = Calendar(identifier: calendarIdentifier)
    calendar.locale = locale

    self.init(calendar: calendar, currentDate: Date(), selection: selection, locale: locale)
  }

  init(calendar: Calendar, currentDate: Date, selection: Selection, locale: Locale) {
    var calendar = calendar
    calendar.locale = locale
    self.calendar = calendar
    self.currentDate = currentDate
    self.selection = selection

    updateYearBoundaries()
  }

  private func updateYearBoundaries() {
    guard let minYear = try? convertGregorianYearToCurrentCalendar(Self.minYear) else {
      return
    }
    self.minYear = minYear

    guard let maxYear = try? convertGregorianYearToCurrentCalendar(Self.maxYear) else {
      return
    }
    self.maxYear = maxYear
  }

  func convertGregorianYearToCurrentCalendar(_ year: Int) throws -> Int {
    guard
      let gregorianDate = gregorianCalendar.date(
        from: DateComponents(
          year: year,
          month: 1,
          day: 1))
    else {
      throw Calendar.CalendarError.cannotCalculateDate
    }

    return calendar.component(.year, from: gregorianDate)
  }

  /// Updates the calendar identifier and locale, retaining selection and current date.
  ///
  /// Use this when a user switches calendar systems from a picker. Existing selected `Date`
  /// values are preserved because `Date` is calendar independent.
  ///
  /// - Parameter identifier: The new calendar system to use.
  ///
  /// ```swift
  /// calendar.updateCalendar(identifier: .hebrew)
  /// ```
  public func updateCalendar(identifier: Calendar.Identifier) {
    let locale = Self.locale(for: identifier)
    var calendar = Calendar(identifier: identifier)
    calendar.locale = locale
    self.calendar = calendar
  }

  /// Clamps `preferredDay` into the target month and returns the resolved date, if any.
  func resolvedDate(year: Int, month: Int, preferredDay: Int) -> Date? {
    guard let startOfMonth = firstDate(month: month, year: year) else {
      return nil
    }

    let numberOfDays = (try? calendar.numberOfDays(for: startOfMonth)) ?? 1
    let clampedDay = min(max(preferredDay, 1), numberOfDays)
    return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
  }

  func date(byAddingMonths months: Int, to date: Date) -> Date? {
    calendar.date(byAdding: .month, value: months, to: date)
  }

  func isWithinSupportedYear(_ date: Date) -> Bool {
    let year = calendar.year(from: date)
    return (minYear...maxYear).contains(year)
  }

  private static func locale(for identifier: Calendar.Identifier) -> Locale {
    var locale = Locale(calendarIdentifier: identifier)
    switch identifier {
    case .persian:
      locale = locale.withNumberingSystemIdentifier(.arabExtended)
    case .islamic, .islamicCivil, .islamicUmmAlQura, .islamicTabular:
      locale = locale.withNumberingSystemIdentifier(.arab)
    default:
      break
    }
    return locale
  }
}

extension Calendar.Identifier {
  /// Whether this calendar system's native script is written right-to-left.
  ///
  /// Used to drive `CalendarViewModel.layoutDirection` so calendars like Hebrew and Islamic stay
  /// mirrored even when the resolved system locale reports a left-to-right language.
  var prefersRightToLeftLayout: Bool {
    switch self {
    case .hebrew, .islamic, .islamicCivil, .islamicUmmAlQura, .islamicTabular, .persian:
      return true
    default:
      return false
    }
  }
}

// MARK: Testing

extension CalendarViewModel {
  static func test(
    identifier: Calendar.Identifier = .gregorian, selection: Selection = .single(nil)
  ) -> CalendarViewModel {
    CalendarViewModel(calendarIdentifier: identifier, selection: selection)
  }
}
