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
  public typealias Selection = CalendarSelection

  struct MonthMetadata: Equatable {
    let identifier: MonthIdentifier
    let numberOfDays: Int
    var month: Int { identifier.month }
    var year: Int { identifier.year }
  }

  // MARK: - Properties

  /// The earliest supported year in the visible era. Relative navigation can cross eras.
  public private(set) var minYear: Int
  /// The latest supported year in the visible era.
  public private(set) var maxYear: Int

  private let gregorianCalendar = Calendar(identifier: .gregorian)

  private let logger = Logger.swiftUICalendar(for: CalendarViewModel.self)

  var engine: CalendarEngine { CalendarEngine(calendar: calendar) }

  private var calendar: Calendar {
    didSet {
      updateYearBoundaries(including: currentDate)
    }
  }

  var headerTitles: [String] {
    calendar.veryShortWeekdaySymbols
  }

  var locale: Locale {
    calendar.locale ?? Locale(calendarIdentifier: calendar.identifier)
  }

  /// The identifier of the active calendar system.
  ///
  /// Call ``updateCalendar(identifier:)`` to change this value while preserving the represented
  /// dates in the current selection.
  public var calendarIdentifier: Calendar.Identifier {
    calendar.identifier
  }

  var calendarSignature: String {
    "\(calendar.identifier)-\(locale.identifier)"
  }

  var startOfMonthDay: Int {
    engine.start(of: visibleMonth).map { calendar.component(.weekday, from: $0) } ?? 1
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
    calendar.range(of: .day, in: .month, for: currentDate)?.count ?? 30
  }

  var currentMonthName: String {
    monthSymbol(for: visibleMonth)
  }

  public internal(set) var currentYear: Int {
    get {
      calendar.year(from: currentDate)
    }
    set {
      try? navigate(toYear: newValue)
    }
  }

  public internal(set) var currentMonth: Int {
    get {
      calendar.month(from: currentDate)
    }
    set {
      try? navigate(toMonth: newValue, year: currentYear)
    }
  }

  var monthSymbols: [String] {
    calendar.monthSymbols
  }

  var canNavigateToPreviousMonth: Bool { monthIdentifier(offset: -1) != nil }
  var canNavigateToNextMonth: Bool { monthIdentifier(offset: 1) != nil }
  var canNavigateToPreviousYear: Bool { relativeYearDate(-1) != nil }
  var canNavigateToNextYear: Bool { relativeYearDate(1) != nil }

  /// Current selection state for the calendar.
  ///
  /// Read this value to respond to user selection, or assign a new value to programmatically
  /// change modes or selected dates.
  ///
  /// ```swift
  /// calendar.selection = .multiple([])
  /// ```
  public var selection: Selection {
    get { storedSelection }
    set { storedSelection = newValue.normalized(in: calendar) }
  }

  private var storedSelection: Selection

  /// The date representing the currently visible month.
  ///
  /// Use `try calendar.navigate(to: date)` to change the visible month. The supported interval
  /// is January 1, 1900 through December 31, 2100 in the Gregorian calendar.
  public internal(set) var currentDate: Date {
    get { storedCurrentDate }
    set {
      guard isWithinSupportedYear(newValue) else {
        logger.error("Ignoring currentDate outside the supported calendar range")
        return
      }
      storedCurrentDate = newValue
    }
  }

  /// Stable calendar components for the currently visible month.
  public var visibleMonth: MonthIdentifier {
    engine.month(containing: currentDate)
  }

  /// Moves the calendar to an absolute date within its supported range.
  public func navigate(to date: Date) throws {
    guard isWithinSupportedYear(date) else {
      logger.error("Cannot navigate outside the supported calendar range")
      throw Calendar.CalendarError.cannotCalculateDate
    }
    storedCurrentDate = date
  }

  /// Moves to a regular month in the current era, preserving the day when possible.
  /// Use `navigate(toMonth:)` with a complete identifier for leap months or another era.
  public func navigate(toMonth month: Int, year: Int) throws {
    guard
      let identifier = months(in: year).first(where: {
        $0.month == month && $0.identifier.isLeapMonth == false
      })?.identifier
    else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    try navigateInVisibleEra(toMonth: identifier)
  }

  /// Moves to an unambiguous month, including leap months and historical eras.
  public func navigate(toMonth month: MonthIdentifier) throws {
    guard
      let date = engine.navigationDate(
        in: month, preferredDay: calendar.component(.day, from: currentDate))
    else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    try navigate(to: date)
  }

  /// Moves to a year in the currently visible era. Boundary years clamp to a supported date.
  public func navigate(toYear year: Int) throws {
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

  func navigateInVisibleEra(toMonth month: MonthIdentifier) throws {
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

  private var storedCurrentDate: Date {
    didSet { updateYearBoundaries(including: storedCurrentDate) }
  }

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

  private init(calendar: Calendar, currentDate: Date, selection: Selection, locale: Locale) {
    var calendar = calendar
    calendar.locale = locale
    let bounds = CalendarEngine(calendar: calendar).yearBounds(containing: currentDate)
    self.minYear = bounds.lowerBound
    self.maxYear = bounds.upperBound
    self.calendar = calendar
    self.storedCurrentDate = currentDate
    self.storedSelection = selection.normalized(in: calendar)

    updateYearBoundaries(including: currentDate)
  }

  private func updateYearBoundaries(including currentDate: Date? = nil) {
    let bounds = engine.yearBounds(containing: currentDate ?? self.currentDate)
    minYear = bounds.lowerBound
    maxYear = bounds.upperBound
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

  func updateMonthToNextMonth() throws {
    try updateMonth(byAdding: 1)
  }

  /// Moves the calendar by a relative number of months, preserving the day when possible.
  ///
  /// Throws `Calendar.CalendarError.cannotCalculateDate` when the offset cannot be
  /// computed or the target month falls outside the supported navigation range.
  public func updateMonth(byAdding months: Int) throws {
    guard months != 0 else { return }
    guard let month = monthIdentifier(offset: months) else {
      throw Calendar.CalendarError.cannotCalculateDate
    }
    try navigate(toMonth: month)
  }

  func updateMonthToPreviousMonth() throws {
    try updateMonth(byAdding: -1)
  }

  private func relativeYearDate(_ offset: Int) -> Date? {
    guard let date = calendar.date(byAdding: .year, value: offset, to: currentDate),
      let interval = calendar.dateInterval(of: .year, for: date),
      engine.intersectsSupportedDates(interval)
    else { return nil }
    return min(
      max(date, engine.supportedDates.lowerBound),
      engine.supportedDates.upperBound.addingTimeInterval(-1))
  }

  func updateYearToNextYear() throws {
    guard let date = relativeYearDate(1) else { throw Calendar.CalendarError.cannotCalculateDate }
    try navigate(to: date)
  }

  func updateYearToPreviousYear() throws {
    guard let date = relativeYearDate(-1) else { throw Calendar.CalendarError.cannotCalculateDate }
    try navigate(to: date)
  }

  private func metadata(for date: Date) -> MonthMetadata {
    let identifier = engine.month(containing: date)
    return MonthMetadata(
      identifier: identifier,
      numberOfDays: calendar.range(of: .day, in: .month, for: date)?.count ?? 0)
  }

  func monthMetadata(offset: Int) -> MonthMetadata? {
    calendar.date(byAdding: .month, value: offset, to: currentDate).map(metadata(for:))
  }

  func monthMetadata(month: Int, year: Int) -> MonthMetadata? {
    months(in: year).first(where: { $0.month == month })
  }

  func monthMetadata(month: Int, year: Int, offset: Int) -> MonthMetadata? {
    guard let start = firstDate(month: month, year: year),
      let date = calendar.date(byAdding: .month, value: offset, to: start)
    else { return nil }
    return metadata(for: date)
  }

  func months(in year: Int) -> [MonthMetadata] {
    engine.months(in: year, relativeTo: currentDate).compactMap { identifier in
      engine.start(of: identifier).map(metadata(for:))
    }
  }

  func date(for day: Int) -> Date? {
    engine.date(day: day, in: visibleMonth)
  }

  func date(for day: Int, month: Int, year: Int) -> Date? {
    engine.date(day: day, in: componentMonth(month: month, year: year))
  }

  func componentMonth(month: Int, year: Int) -> MonthIdentifier {
    if month == visibleMonth.month && year == visibleMonth.year { return visibleMonth }
    return MonthIdentifier(
      month: month, year: year, calendarIdentifier: calendar.identifier,
      era: calendar.component(.era, from: currentDate))
  }

  func startOfMonthDay(month: Int, year: Int) -> Int {
    firstDate(month: month, year: year).map { calendar.component(.weekday, from: $0) } ?? 1
  }

  func numberOfDaysInMonth(month: Int, year: Int) -> Int {
    guard let date = firstDate(month: month, year: year) else { return numberOfDaysInMonth }
    return calendar.range(of: .day, in: .month, for: date)?.count ?? numberOfDaysInMonth
  }

  func rowCount(month: Int, year: Int) -> Int {
    monthSnapshot(for: componentMonth(month: month, year: year))?.rowCount ?? 1
  }

  func monthIdentifier(offset: Int = 0, from identifier: MonthIdentifier? = nil) -> MonthIdentifier?
  {
    engine.month(offset: offset, from: identifier ?? visibleMonth)
  }

  func monthSnapshot(for identifier: MonthIdentifier) -> MonthSnapshot? {
    guard let start = engine.start(of: identifier),
      let count = calendar.range(of: .day, in: .month, for: start)?.count
    else { return nil }
    let leading = calendar.component(.weekday, from: start) - 1
    let total = ((leading + count + 6) / 7) * 7
    let days = (0..<total).compactMap { index -> MonthSnapshot.Day? in
      guard let date = calendar.date(byAdding: .day, value: index - leading, to: start) else {
        return nil
      }
      let day = calendar.component(.day, from: date)
      return MonthSnapshot.Day(
        id: "day-\(date.timeIntervalSinceReferenceDate)", date: date, day: day,
        dayLabel: NumberFormatter.formatDay(day, locale: locale),
        month: calendar.component(.month, from: date), year: calendar.component(.year, from: date),
        isInDisplayedMonth: index >= leading && index < leading + count,
        isToday: calendar.isDateInToday(date), isSelected: isSelected(date: date))
    }
    return MonthSnapshot(id: identifier, title: monthSymbol(for: identifier), days: days)
  }

  func monthSymbol(for month: Int) -> String {
    monthSymbol(for: month, year: currentYear)
  }

  func monthSymbol(for month: Int, year: Int) -> String {
    monthSymbol(for: componentMonth(month: month, year: year))
  }

  func monthSymbol(for identifier: MonthIdentifier) -> String {
    guard let date = engine.start(of: identifier) else { return "" }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "LLLL"
    return formatter.string(from: date)
  }

  func yearTitle(_ year: Int) -> String {
    let number = NumberFormatter.formatYear(year, locale: locale)
    guard calendar.identifier == .japanese || calendar.identifier == .chinese else { return number }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = "G"
    return "\(formatter.string(from: currentDate)) \(number)"
  }

  func firstDate(month: Int, year: Int) -> Date? {
    engine.start(of: componentMonth(month: month, year: year))
  }

  private func isWithinSupportedYear(_ date: Date) -> Bool { engine.contains(date) }

  func isToday(_ day: Int) -> Bool {
    date(for: day).map(calendar.isDateInToday) ?? false
  }

  func isToday(day: Int, month: Int, year: Int) -> Bool {
    date(for: day, month: month, year: year).map(calendar.isDateInToday) ?? false
  }

  func isSelected(_ day: Int) -> Bool {
    guard let date = date(for: day) else { return false }
    return isSelected(date: date)
  }

  func isSelected(date: Date) -> Bool {
    selection.contains(date, in: calendar)
  }

  func select(_ date: Date) {
    selection = selection.selecting(date, in: calendar)
  }

  // MARK: - Today navigation

  func goToToday() {
    let today = Date()
    currentDate = today

    if case .single = selection {
      selection = .single(calendar.startOfDay(for: today))
    }
  }

  private static func locale(for identifier: Calendar.Identifier) -> Locale {
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
