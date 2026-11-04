#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Unbounded calendar growth", .serialized)
struct CalendarUnboundedGrowthTests {
    @MainActor
    final class HeightMeasurement {
        var height: CGFloat = 0
    }

    @Test(
        "Tall custom content fits its ideal height in a parent scroll view",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal],
        [Calendar.Identifier.gregorian, .persian])
    func tallContentFits(mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier)
        throws
    {
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(nil))
        let frames = MeasuredDayFrames(month: model.visibleMonth, calendar: model.engine.calendar)
        let height = HeightMeasurement()
        let theme = Theme()
        theme.day.setDayContent(
            minimumSize: { _ in CGSize(width: 44, height: 100) },
            { MeasuringDayView(context: $0, frames: frames) })
        let hosted = hostView(
            ScrollView {
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        height.height = $0
                    }
            }, size: CGSize(width: 390, height: 1100))
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        #expect(height.height >= 780)
        #expect(!frames.inMonth.isEmpty)
        for frame in frames.inMonth.values {
            #expect(frame.height >= 100)
            #expect(frame.maxY <= height.height + 0.5)
        }
    }

    @Test(
        "Book panels keep a compact ideal height in a parent scroll view",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal, .vertical])
    func foldedHeightDoesNotGrow(mode: CalendarConfiguration.ScrollMode) throws {
        let model = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let frames = MeasuredDayFrames(month: model.visibleMonth, calendar: model.engine.calendar)
        let height = HeightMeasurement()
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            ScrollView {
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                    .environment(
                        \.calendarFoldRegions, [CGRect(x: 630, y: 0, width: 40, height: 1100)]
                    )
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.height
                    } action: {
                        height.height = $0
                    }
            }, size: CGSize(width: 1300, height: 1100))
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        #expect(height.height < 600)
        #expect(!frames.inMonth.isEmpty)
        for frame in frames.inMonth.values {
            #expect(frame.height <= 64.5)
        }
    }

    @Test("Fixed-month transitions preserve navigation and selection")
    func monthTransitions() throws {
        let model = CalendarViewModel.test(identifier: .gregorian, selection: .single(nil))
        let selected = try #require(model.engine.date(day: 12, in: model.visibleMonth))
        model.select(selected)
        let hosted = hostView(
            CalendarView(model: model),
            size: CGSize(width: 390, height: 900))
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        let original = model.visibleMonth
        try model.updateMonthToNextMonth()
        #expect(waitForStableRender(hosted.hosting))
        #expect(model.visibleMonth != original)
        #expect(model.selection == .single(selected))
        try model.updateMonthToPreviousMonth()
        #expect(waitForStableRender(hosted.hosting))
        #expect(model.visibleMonth == original)
        #expect(model.selection == .single(selected))
        expectNonBlankRender(
            hosted.hosting, size: CGSize(width: 390, height: 900), "month transition")
    }
}
#endif
