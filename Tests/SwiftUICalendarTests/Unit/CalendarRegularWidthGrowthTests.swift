#if os(iOS)
import SwiftUI
import Testing
import UIKit

@testable import SwiftUICalendar

/// Cells grow past the phone-sized ceiling only at a regular width. Split View, Stage Manager and
/// slide-over windows report a compact width at any size, so they must keep the old sizing.
@MainActor
@Suite("Regular-width cell growth", .serialized)
struct CalendarRegularWidthGrowthTests {
    private func widestCell(
        mode: CalendarConfiguration.ScrollMode,
        sizeClass: UIUserInterfaceSizeClass,
        size: CGSize
    ) throws -> CGFloat {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let month = try #require(model.monthIdentifier())
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
            size: size)
        defer { hosted.window.isHidden = true }
        hosted.hosting.traitOverrides.horizontalSizeClass = sizeClass
        settle(hosted.hosting.view)
        return try #require(frames.widestCell)
    }

    @Test("A regular-width fixed month grows past the phone-sized ceiling")
    func regularFixedGrows() throws {
        let widest = try widestCell(
            mode: .none, sizeClass: .regular, size: CGSize(width: 820, height: 1180))
        #expect(widest > CalendarMetrics.default.maxCellSize)
    }

    @Test("A regular-width horizontal month grows past the phone-sized ceiling")
    func regularHorizontalGrows() throws {
        let widest = try widestCell(
            mode: .horizontal, sizeClass: .regular, size: CGSize(width: 820, height: 1180))
        #expect(widest > CalendarMetrics.default.maxCellSize)
    }

    @Test(
        "A compact width keeps the phone-sized ceiling however wide the window is",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical])
    func compactKeepsCeiling(mode: CalendarConfiguration.ScrollMode) throws {
        let widest = try widestCell(
            mode: mode, sizeClass: .compact, size: CGSize(width: 820, height: 1180))
        #expect(widest <= CalendarMetrics.default.maxCellSize + 0.5)
    }

    @Test("A regular-width vertical list grows past the phone-sized ceiling")
    func regularVerticalGrows() throws {
        let widest = try widestCell(
            mode: .vertical, sizeClass: .regular, size: CGSize(width: 820, height: 1180))
        #expect(widest > CalendarMetrics.default.maxCellSize)
    }

    @Test("A regular-width window too short to fit a grown month keeps the old sizing")
    func shortRegularKeepsCeiling() throws {
        let widest = try widestCell(
            mode: .none, sizeClass: .regular, size: CGSize(width: 820, height: 420))
        #expect(widest <= CalendarMetrics.default.maxCellSize + 0.5)
    }
}
#endif
