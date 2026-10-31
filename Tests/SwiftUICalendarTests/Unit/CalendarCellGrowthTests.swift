import SwiftUI
import Testing

@testable import SwiftUICalendar

@Suite("Cell growth policy")
struct CalendarCellGrowthTests {
    nonisolated private static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .horizontal, .vertical,
    ]

    #if os(macOS)
    @Test("macOS grows the fixed and horizontal months whatever the size class", arguments: modes)
    func macGrowth(mode: CalendarConfiguration.ScrollMode) {
        let expected = mode != .vertical
        #expect(CalendarCellGrowth.isAllowed(sizeClass: nil, scrollMode: mode) == expected)
        #expect(CalendarCellGrowth.isAllowed(sizeClass: .compact, scrollMode: mode) == expected)
    }
    #else
    @Test("iOS grows every mode at a regular width only", arguments: modes)
    func iosGrowth(mode: CalendarConfiguration.ScrollMode) {
        #expect(CalendarCellGrowth.isAllowed(sizeClass: .regular, scrollMode: mode))
        #expect(!CalendarCellGrowth.isAllowed(sizeClass: .compact, scrollMode: mode))
        #expect(!CalendarCellGrowth.isAllowed(sizeClass: nil, scrollMode: mode))
    }
    #endif
}
