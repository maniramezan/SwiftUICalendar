import SwiftCommons
import SwiftUI
import OSLog

/// View model that drives calendar layout, selection, and navigation state.
@Observable public class CalendarViewModel {

    // MARK: - Selection mode

    /// Selection mode for the calendar.
    public enum Selection: Equatable {
        /// A single selected date.
        case single(_ date: Date? = nil)
        /// A contiguous range defined by start and end dates.
        case range(Date? = nil, Date? = nil)
        /// Multiple discrete selected dates.
        case multiple(Set<Date> = [])
    }
    
    struct MonthMetadata: Equatable {
        let month: Int
        let year: Int
        let numberOfDays: Int
    }

    // MARK: - Properties
    
    // MARK: UI Configurations
    
    /// Controls whether the month header is shown.
    public var showHeader: Bool = true

    private static let minYear = 1900
    private static let maxYear = 2100

    private(set) var minYear = CalendarViewModel.minYear
    private(set) var maxYear = CalendarViewModel.maxYear

    private let gregorianCalendar = Calendar(identifier: .gregorian)
    
    private let logger = Logger.swiftUICalendar(for: CalendarViewModel.self)

    private var calendar: Calendar {
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
                  isWithinSupportedYear(updatedDate) else {
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
                  isWithinSupportedYear(updatedDate) else {
                return
            }
            currentDate = updatedDate
        }
    }

    var monthSymbols: [String] {
        calendar.monthSymbols
    }

    var canNavigateToPreviousMonth: Bool {
        guard let updatedDate = try? calendar.sameDay(currentDate, byAddingMonths: -1) else {
            return false
        }
        return isWithinSupportedYear(updatedDate)
    }

    var canNavigateToNextMonth: Bool {
        guard let updatedDate = try? calendar.sameDay(currentDate, byAddingMonths: 1) else {
            return false
        }
        return isWithinSupportedYear(updatedDate)
    }

    var canNavigateToPreviousYear: Bool {
        guard let updatedDate = try? calendar.previousYear(for: currentDate) else {
            return false
        }
        return isWithinSupportedYear(updatedDate)
    }

    var canNavigateToNextYear: Bool {
        guard let updatedDate = try? calendar.nextYear(for: currentDate) else {
            return false
        }
        return isWithinSupportedYear(updatedDate)
    }

    /// Current selection state for the calendar.
    public var selection: Selection

    /// The date representing the currently visible month.
    public var currentDate: Date

    /// Creates a view model for a given calendar system and selection mode.
    /// - Parameters:
    ///   - calendarIdentifier: The calendar system to use.
    ///   - selection: Initial selection state.
    public convenience init(calendarIdentifier: Calendar.Identifier, selection: Selection = .single(nil)) {
        let locale = Self.locale(for: calendarIdentifier)
        var calendar = Calendar(identifier: calendarIdentifier)
        calendar.locale = locale

        self.init(calendar: calendar, currentDate: Date(), selection: selection, locale: locale)
    }

    private init(calendar: Calendar, currentDate: Date, selection: Selection, locale: Locale) {
        var calendar = calendar
        calendar.locale = locale
        self.calendar = calendar
        self.currentDate = currentDate
        self.selection = selection

        updateYearBoundaries()
    }

    private func updateYearBoundaries() {
        guard let minYear = try? convertGregorianYearToCurrentCalendar(Self.minYear) else{
            return
        }
        self.minYear = minYear

        guard let maxYear = try? convertGregorianYearToCurrentCalendar(Self.maxYear) else {
            return
        }
        self.maxYear = maxYear
    }

    func convertGregorianYearToCurrentCalendar(_ year: Int) throws -> Int {
        guard let gregorianDate = gregorianCalendar.date(from: DateComponents(
            year: year,
            month: 1,
            day: 1))
        else {
            throw Calendar.CalendarError.cannotCalculateDate
        }

        return calendar.component(.year, from: gregorianDate)
    }

    /// Updates the calendar identifier and locale, retaining selection and current date.
    /// - Parameter identifier: The new calendar system to use.
    public func updateCalendar(identifier: Calendar.Identifier) {
        let locale = Self.locale(for: identifier)
        var calendar = Calendar(identifier: identifier)
        calendar.locale = locale
        self.calendar = calendar
    }

    func updateMonthToNextMonth() throws {
        guard let startOfCurrentMonth = firstDate(month: currentMonth, year: currentYear),
              let updatedDate = calendar.date(byAdding: .month, value: 1, to: startOfCurrentMonth),
              isWithinSupportedYear(updatedDate) else {
            throw Calendar.CalendarError.cannotCalculateNextMonthFirstDate
        }

        currentDate = updatedDate
    }

    func updateMonth(byAdding months: Int) throws {
        let updatedDate = try calendar.sameDay(currentDate, byAddingMonths: months)
        guard isWithinSupportedYear(updatedDate) else {
            throw Calendar.CalendarError.cannotCalculateDate
        }

        currentDate = updatedDate
    }

    func updateMonthToPreviousMonth() throws {
        guard let startOfCurrentMonth = firstDate(month: currentMonth, year: currentYear),
              let updatedDate = calendar.date(byAdding: .month, value: -1, to: startOfCurrentMonth),
              isWithinSupportedYear(updatedDate) else {
            throw Calendar.CalendarError.cannotCalculatePreviousMonthFirstDate
        }

        currentDate = updatedDate
    }

    func updateYearToNextYear() throws {
        let updatedDate = try calendar.nextYear(for: currentDate)
        guard isWithinSupportedYear(updatedDate) else {
            throw Calendar.CalendarError.cannotCalculateDate
        }

        currentDate = updatedDate
    }

    func updateYearToPreviousYear() throws {
        let updatedDate = try calendar.previousYear(for: currentDate)
        guard isWithinSupportedYear(updatedDate) else {
            throw Calendar.CalendarError.cannotCalculateDate
        }

        currentDate = updatedDate
    }

    func copy(addMonths: Int) throws -> CalendarViewModel {
        let calendarViewModel = CalendarViewModel(
            calendar: calendar,
            currentDate: currentDate,
            selection: selection,
            locale: locale)
        try calendarViewModel.updateMonth(byAdding: addMonths)
        return calendarViewModel
    }
    
    func monthMetadata(offset: Int) -> MonthMetadata? {
        if offset == 0 {
            return MonthMetadata(
                month: currentMonth,
                year: currentYear,
                numberOfDays: numberOfDaysInMonth
            )
        }
        guard let targetDate = try? calendar.sameDay(currentDate, byAddingMonths: offset) else {
            return nil
        }
        let month = calendar.month(from: targetDate)
        let year = calendar.year(from: targetDate)
        let numberOfDays = (try? calendar.numberOfDays(for: targetDate)) ?? numberOfDaysInMonth
        return MonthMetadata(month: month, year: year, numberOfDays: numberOfDays)
    }

    func monthMetadata(month: Int, year: Int) -> MonthMetadata? {
        months(in: year).first(where: { $0.month == month })
    }

    func monthMetadata(month: Int, year: Int, offset: Int) -> MonthMetadata? {
        guard let date = firstDate(month: month, year: year),
              let targetDate = try? calendar.sameDay(date, byAddingMonths: offset) else {
            return nil
        }

        let targetMonth = calendar.month(from: targetDate)
        let targetYear = calendar.year(from: targetDate)
        let numberOfDays = (try? calendar.numberOfDays(for: targetDate)) ?? numberOfDaysInMonth
        return MonthMetadata(month: targetMonth, year: targetYear, numberOfDays: numberOfDays)
    }

    func months(in year: Int) -> [MonthMetadata] {
        guard let startDate = firstDate(month: 1, year: year) else {
            return []
        }

        var months: [MonthMetadata] = []
        var visitedMonths = Set<Int>()
        var date = startDate

        while calendar.year(from: date) == year {
            let month = calendar.month(from: date)
            if visitedMonths.insert(month).inserted {
                let numberOfDays = (try? calendar.numberOfDays(for: date)) ?? 0
                months.append(MonthMetadata(month: month, year: year, numberOfDays: numberOfDays))
            }

            guard let nextDate = calendar.date(byAdding: .month, value: 1, to: date) else {
                break
            }
            date = nextDate
        }

        return months
    }

    func date(for day: Int) -> Date {
        guard let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) else {
            logger.error("Cannot create date from components for day: \(day)")
            return Date()
        }
        return date
    }
    
    func date(for day: Int, month: Int, year: Int) -> Date {
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else {
            logger.error("Cannot create date from components for day: \(day) month: \(month) year: \(year)")
            return Date()
        }
        return date
    }

    func startOfMonthDay(month: Int, year: Int) -> Int {
        guard let date = firstDate(month: month, year: year) else {
            return 1
        }
        return (try? calendar.startOfMonthDay(for: date)) ?? 1
    }

    func numberOfDaysInMonth(month: Int, year: Int) -> Int {
        guard let date = firstDate(month: month, year: year) else {
            return numberOfDaysInMonth
        }
        return (try? calendar.numberOfDays(for: date)) ?? numberOfDaysInMonth
    }

    func rowCount(month: Int, year: Int) -> Int {
        let leadingEmptyDaysCount = max(startOfMonthDay(month: month, year: year) - 1, 0)
        let totalDaysToRender = leadingEmptyDaysCount + numberOfDaysInMonth(month: month, year: year)
        let remainder = totalDaysToRender % 7
        let trailingEmptyDaysCount = remainder == 0 ? 0 : 7 - remainder
        return max(1, (totalDaysToRender + trailingEmptyDaysCount) / 7)
    }

    func monthSymbol(for month: Int) -> String {
        monthSymbol(for: month, year: currentYear)
    }

    func monthSymbol(for month: Int, year: Int) -> String {
        guard let date = firstDate(month: month, year: year) else {
            return ""
        }

        return calendar.monthSymbol(for: date)
    }

    func firstDate(month: Int, year: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: 1))
    }

    private func resolvedDate(year: Int, month: Int, preferredDay: Int) -> Date? {
        guard let startOfMonth = firstDate(month: month, year: year) else {
            return nil
        }

        let numberOfDays = (try? calendar.numberOfDays(for: startOfMonth)) ?? 1
        let clampedDay = min(max(preferredDay, 1), numberOfDays)
        return calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
    }

    private func isWithinSupportedYear(_ date: Date) -> Bool {
        let year = calendar.year(from: date)
        return (minYear...maxYear).contains(year)
    }

    func isToday(_ day: Int) -> Bool {
        calendar.isToday(day: day, month: currentMonth, year: currentYear)
    }

    func isToday(day: Int, month: Int, year: Int) -> Bool {
        calendar.isToday(day: day, month: month, year: year)
    }

    func isSelected(_ day: Int) -> Bool {
        isSelected(date: date(for: day))
    }

    func isSelected(date: Date) -> Bool {
        let normalized = normalizedDate(date)
        switch selection {
        case .single(let selectedDate):
            guard let selectedDate else { return false }
            return isSameDay(selectedDate, normalized)
        case .range(let start, let end):
            if let start, let end {
                let normalizedStart = normalizedDate(start)
                let normalizedEnd = normalizedDate(end)
                return normalized >= normalizedStart && normalized <= normalizedEnd
            } else if let start {
                return isSameDay(start, normalized)
            } else {
                return false
            }
        case .multiple(let dates):
            return dates.contains { stored in
                isSameDay(stored, normalized)
            }
        }
    }

    func select(_ date: Date) {
        let normalized = normalizedDate(date)
        switch selection {
        case .single(let selectedDate):
            // Toggle: deselect if tapping the already selected date
            if let selectedDate, isSameDay(selectedDate, normalized) {
                selection = .single(nil)
            } else {
                selection = .single(normalized)
            }

        case .range(let start, let end):
            // Keep existing behavior, plus a small toggle:
            // If only start is set and user taps it again, clear it.
            if end == nil, let start, isSameDay(start, normalized) {
                selection = .range(nil, nil)
                return
            }

            if start == nil {
                selection = .range(normalized, nil)
            } else if end == nil, let start {
                let normalizedStart = normalizedDate(start)
                if normalized >= normalizedStart {
                    selection = .range(normalizedStart, normalized)
                } else {
                    selection = .range(normalized, normalizedStart)
                }
            } else {
                selection = .range(normalized, nil)
            }

        case .multiple(var dates):
            if let existing = dates.first(where: { isSameDay($0, normalized) }) {
                dates.remove(existing)
            } else {
                dates.insert(normalized)
            }
            selection = .multiple(dates)
        }
    }

    // MARK: - Today navigation

    func goToToday() {
        currentDate = Date()
    }

    private func normalizedDate(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
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

// MARK: Testing

extension CalendarViewModel {
    static func test(identifier: Calendar.Identifier = .gregorian, selection: Selection = .single(nil)) -> CalendarViewModel {
        CalendarViewModel(calendarIdentifier: identifier, selection: selection)
    }
}
