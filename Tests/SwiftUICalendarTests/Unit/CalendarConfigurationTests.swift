import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar Configuration Tests")
struct CalendarConfigurationTests {
    @Test("default configuration is a fixed calendar with a header")
    func defaultConfiguration() {
        let configuration = CalendarConfiguration()

        #expect(configuration.scrollMode == .none)
        #expect(configuration.horizontalHeightMode == .sixRows)
        #expect(configuration.gridSizing == .adaptive)
        #expect(configuration.showsHeader)
        #expect(configuration.yearSelection == .init())
    }

    @Test("configuration is an independent value")
    func configurationHasValueSemantics() {
        var first = CalendarConfiguration(scrollMode: .horizontal)
        let second = first

        first.scrollMode = .vertical

        #expect(first.scrollMode == .vertical)
        #expect(second.scrollMode == .horizontal)
    }

    @Test("configuration preserves the requested grid sizing")
    func configurationPreservesGridSizing() {
        #expect(CalendarConfiguration(gridSizing: .compact).gridSizing == .compact)
        #expect(CalendarConfiguration(gridSizing: .flexible).gridSizing == .flexible)
    }

    // MARK: - Keyboard navigation

    @Test("every shortcut is enabled by default")
    func keyboardNavigationDefaultsToAll() {
        let configuration = CalendarConfiguration()
        #expect(configuration.keyboardNavigation == .all)
        #expect(configuration.keyboardNavigation.contains(.arrows))
        #expect(configuration.keyboardNavigation.contains(.monthShortcuts))
        #expect(configuration.keyboardNavigation.contains(.today))
    }

    @Test("a host can decline individual shortcuts")
    func keyboardNavigationSubsets() {
        let withoutToday = CalendarConfiguration(
            keyboardNavigation: [.arrows, .monthShortcuts])
        #expect(withoutToday.keyboardNavigation.contains(.arrows))
        #expect(withoutToday.keyboardNavigation.contains(.monthShortcuts))
        #expect(!withoutToday.keyboardNavigation.contains(.today))

        let none = CalendarConfiguration(keyboardNavigation: [])
        #expect(none.keyboardNavigation.isEmpty)
        #expect(!none.keyboardNavigation.contains(.arrows))
    }
}
