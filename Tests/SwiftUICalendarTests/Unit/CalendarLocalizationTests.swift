import Foundation
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar localization")
struct CalendarLocalizationTests {
    @Test(
        "Controls honor the requested calendar language",
        arguments: [
            ["fa_IR", "امروز", "انجام شد"], ["ar_SA", "اليوم", "تم"],
            ["he_IL", "היום", "סיום"], ["de_DE", "Heute", "Fertig"],
            ["en_US", "Today", "Done"], ["fr_FR", "Today", "Done"],
        ])
    func controls(values: [String]) {
        let locale = Locale(identifier: values[0])
        #expect("Calendar.Today".localized(locale: locale) == values[1])
        #expect("Calendar.Done".localized(locale: locale) == values[2])
    }

    @Test(
        "Formatted labels keep arguments in the requested translation",
        arguments: ["fa", "ar", "he", "de"])
    func formatted(language: String) {
        let locale = Locale(identifier: language)
        let label = "Calendar.Navigation.Year.Selected".localized(locale: locale, with: "2025")
        #expect(label.contains("2025"))
        #expect(!label.contains("Selected year"))
        #expect(!label.contains("%@"))
    }
}
