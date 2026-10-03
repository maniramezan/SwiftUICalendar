import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// Model-level coverage across every calendar system and a spread of real locales.
///
/// The library derives its locale from the calendar identifier, so these tests also build states
/// with an explicit locale (as a host app embedding `CalendarState(calendar:)` would) to pin week
/// start, header order, numerals, and writing direction per locale rather than per identifier.
@MainActor
@Suite("Calendar variant matrix")
struct CalendarVariantMatrixTests {
    // MARK: Fixtures

    nonisolated static let identifiers: [Calendar.Identifier] = [
        .gregorian, .buddhist, .chinese, .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem,
        .hebrew, .indian, .islamic, .islamicCivil, .islamicTabular, .islamicUmmAlQura,
        .iso8601, .japanese, .persian, .republicOfChina,
    ]

    /// Every grid sizing × scroll mode × width, as tuples because Swift Testing zips at most two
    /// argument collections.
    nonisolated static let sizingCombos:
        [(CalendarConfiguration.GridSizing, CalendarConfiguration.ScrollMode, CGFloat)] =
            [CalendarConfiguration.GridSizing.adaptive, .compact, .flexible].flatMap { sizing in
                [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal].flatMap { mode in
                    [CGFloat(320), 428, 900].map { (sizing, mode, $0) }
                }
            }

    struct LocaleCase: Sendable, CustomTestStringConvertible {
        let locale: String
        let identifier: Calendar.Identifier
        let rightToLeft: Bool

        var testDescription: String { "\(locale)/\(identifier)" }
    }

    nonisolated static let localeCases: [LocaleCase] = [
        LocaleCase(locale: "en_US", identifier: .gregorian, rightToLeft: false),
        LocaleCase(locale: "en_GB", identifier: .gregorian, rightToLeft: false),
        LocaleCase(locale: "de_DE", identifier: .gregorian, rightToLeft: false),
        LocaleCase(locale: "fr_FR", identifier: .gregorian, rightToLeft: false),
        LocaleCase(locale: "ja_JP", identifier: .gregorian, rightToLeft: false),
        LocaleCase(locale: "ar_SA", identifier: .gregorian, rightToLeft: true),
        LocaleCase(locale: "ar_EG", identifier: .gregorian, rightToLeft: true),
        LocaleCase(locale: "fa_IR", identifier: .gregorian, rightToLeft: true),
        LocaleCase(locale: "fa_IR", identifier: .persian, rightToLeft: true),
        LocaleCase(locale: "he_IL", identifier: .gregorian, rightToLeft: true),
        LocaleCase(locale: "he_IL", identifier: .hebrew, rightToLeft: true),
        LocaleCase(locale: "ar_SA", identifier: .islamicUmmAlQura, rightToLeft: true),
        LocaleCase(locale: "th_TH", identifier: .buddhist, rightToLeft: false),
        LocaleCase(locale: "zh_CN", identifier: .chinese, rightToLeft: false),
    ]

    private static let anchor = DateComponents(year: 2025, month: 6, day: 15, hour: 12)

    private func model(
        locale: String? = nil, identifier: Calendar.Identifier
    ) throws -> CalendarViewModel {
        var calendar = Calendar(identifier: identifier)
        if let locale {
            calendar.locale = Locale(identifier: locale)
        } else {
            calendar.locale = CalendarState.locale(for: identifier)
        }
        let date = try #require(
            Calendar(identifier: .gregorian).date(from: Self.anchor))
        let state = try CalendarState(calendar: calendar, currentDate: date)
        return CalendarViewModel(state: state)
    }

    // MARK: Every calendar system

    @Test("Every calendar system resolves a well-formed visible month", arguments: identifiers)
    func visibleMonthIsWellFormed(identifier: Calendar.Identifier) throws {
        let vm = try model(identifier: identifier)
        let snapshot = try #require(vm.monthSnapshot(for: vm.visibleMonth))
        let calendar = vm.engine.calendar

        let inMonth = snapshot.days.filter(\.isInDisplayedMonth)
        let expected = try #require(
            calendar.range(of: .day, in: .month, for: vm.currentDate)?.count)
        #expect(inMonth.count == expected, "\(identifier): day count")
        #expect((4...6).contains(snapshot.rowCount), "\(identifier): rows=\(snapshot.rowCount)")
        #expect(!snapshot.title.isEmpty)
        #expect(snapshot.days.allSatisfy { $0.isInDisplayedMonth ? !$0.dayLabel.isEmpty : true })
        #expect(vm.headerTitles.count == 7)
    }

    @Test(
        "Every calendar system pages through a year of months in both directions",
        arguments: identifiers)
    func pagesThroughAYear(identifier: Calendar.Identifier) throws {
        let vm = try model(identifier: identifier)
        let calendar = vm.engine.calendar
        var seen = Set<MonthIdentifier>()
        for offset in -14...14 {
            let month = try #require(
                vm.monthIdentifier(offset: offset), "\(identifier): offset \(offset)")
            #expect(seen.insert(month).inserted, "\(identifier): duplicate month at \(offset)")
            let snapshot = try #require(vm.monthSnapshot(for: month))
            let start = try #require(vm.engine.start(of: month))
            let expected = try #require(calendar.range(of: .day, in: .month, for: start)?.count)
            #expect(
                snapshot.days.filter(\.isInDisplayedMonth).count == expected,
                "\(identifier): \(month) day count")
        }
    }

    @Test("Navigating to a date and back lands on the same month", arguments: identifiers)
    func navigationRoundTrip(identifier: Calendar.Identifier) throws {
        let vm = try model(identifier: identifier)
        let origin = vm.visibleMonth
        let later = try #require(
            Calendar(identifier: .gregorian).date(
                from: DateComponents(year: 2027, month: 2, day: 28, hour: 12)))
        let originDate = vm.currentDate
        try vm.navigate(to: later)
        #expect(vm.visibleMonth != origin)
        try vm.navigate(to: originDate)
        #expect(vm.visibleMonth == origin, "\(identifier)")
    }

    @Test("Direction follows calendar identity", arguments: identifiers)
    func directionFollowsIdentity(identifier: Calendar.Identifier) throws {
        let vm = try model(identifier: identifier)
        let expectsRTL = identifier.prefersRightToLeftLayout
        #expect(
            (vm.layoutDirection == .rightToLeft) == expectsRTL,
            "\(identifier): \(vm.layoutDirection)")
    }

    // MARK: Locales

    @Test("Week start, header order and direction follow the locale", arguments: localeCases)
    func localeBehavior(testCase: LocaleCase) throws {
        let vm = try model(locale: testCase.locale, identifier: testCase.identifier)
        let calendar = vm.engine.calendar
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday

        #expect(vm.headerTitles.count == 7)
        #expect(vm.headerTitles.first == symbols[firstWeekday - 1], "\(testCase)")
        #expect(
            (vm.layoutDirection == .rightToLeft) == testCase.rightToLeft,
            "\(testCase): \(vm.layoutDirection)")

        // The first of the month sits in the column its weekday maps to, counted from the
        // locale's first weekday — the grid and the header must agree.
        let snapshot = try #require(vm.monthSnapshot(for: vm.visibleMonth))
        let firstIndex = try #require(snapshot.days.firstIndex { $0.isInDisplayedMonth })
        let startDate = try #require(vm.engine.start(of: vm.visibleMonth))
        let weekday = calendar.component(.weekday, from: startDate)
        #expect(firstIndex % 7 == (weekday - firstWeekday + 7) % 7, "\(testCase)")
        #expect(snapshot.days.count % 7 == 0 || snapshot.days.count > 0)
    }

    @Test("Known first weekdays")
    func knownFirstWeekdays() throws {
        let expectations: [(String, Int)] = [
            ("en_US", 1), ("de_DE", 2), ("fr_FR", 2), ("en_GB", 2), ("ar_SA", 1), ("fa_IR", 7),
        ]
        for (locale, weekday) in expectations {
            let vm = try model(locale: locale, identifier: .gregorian)
            #expect(vm.engine.calendar.firstWeekday == weekday, "\(locale)")
        }
    }

    @Test("Native numerals are used for Persian and Arabic locales")
    func nativeNumerals() throws {
        let persian = try model(identifier: .persian)
        let islamic = try model(identifier: .islamicUmmAlQura)
        let persianDays = try #require(persian.monthSnapshot(for: persian.visibleMonth))
            .days.filter(\.isInDisplayedMonth).map(\.dayLabel)
        let islamicDays = try #require(islamic.monthSnapshot(for: islamic.visibleMonth))
            .days.filter(\.isInDisplayedMonth).map(\.dayLabel)
        let ascii = CharacterSet(charactersIn: "0123456789")
        #expect(persianDays.allSatisfy { $0.unicodeScalars.allSatisfy { !ascii.contains($0) } })
        #expect(islamicDays.allSatisfy { $0.unicodeScalars.allSatisfy { !ascii.contains($0) } })

        let gregorian = try model(locale: "en_US", identifier: .gregorian)
        let gregorianDays = try #require(gregorian.monthSnapshot(for: gregorian.visibleMonth))
            .days.filter(\.isInDisplayedMonth).map(\.dayLabel)
        #expect(gregorianDays.first == "1")
    }

    // MARK: Selection across systems

    @Test(
        "Range selection marks every day between its endpoints in any calendar",
        arguments: identifiers)
    func rangeSelection(identifier: Calendar.Identifier) throws {
        let vm = try model(identifier: identifier)
        let calendar = vm.engine.calendar
        // Endpoints inside the visible month, whatever its length or system.
        let start = try #require(vm.engine.start(of: vm.visibleMonth))
        let end = try #require(calendar.date(byAdding: .day, value: 4, to: start))
        vm.selection = .range(start, end)
        let snapshot = try #require(vm.monthSnapshot(for: vm.visibleMonth))
        let selected = snapshot.days.filter { $0.isInDisplayedMonth && $0.isSelected }
        #expect(selected.count == 5, "\(identifier): \(selected.count) selected")
    }
}
