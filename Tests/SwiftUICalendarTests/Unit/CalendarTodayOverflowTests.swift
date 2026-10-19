#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Today horizontal overflow", .serialized)
struct CalendarTodayOverflowTests {
    @Test(
        "Today reveals its column after manual horizontal scrolling and repeated requests",
        arguments: [CalendarConfiguration.ScrollMode.none, .vertical, .horizontal],
        [Calendar.Identifier.gregorian, .persian])
    func todayRevealsOverflowedColumn(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let now = Date()
        let model = CalendarViewModel.test(identifier: identifier, selection: .single(now))
        let calendar = model.engine.calendar
        let today = calendar.startOfDay(for: now)
        let frames = MeasuredDayFrames(month: model.visibleMonth, calendar: calendar)
        let theme = Theme()
        theme.day.setDayContent(
            minimumSize: { _ in CGSize(width: 100, height: 100) },
            { MeasuringDayView(context: $0, frames: frames) })
        let size = CGSize(width: 240, height: 900)
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                .environment(
                    \.layoutDirection, identifier == .persian ? .rightToLeft : .leftToRight),
            size: size)
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        let columns = try #require(scrollViews(in: hosted.hosting).first)
        let document = try #require(columns.documentView)
        let end = document.frame.width - columns.contentView.bounds.width
        try #require(end > size.width)

        for _ in 0..<2 {
            let frame = try #require(frames.inMonth[today])
            let dayPosition = frame.midX + columns.contentView.bounds.minX
            let offset = dayPosition < document.frame.width / 2 ? end : 0
            columns.contentView.scroll(to: CGPoint(x: offset, y: 0))
            columns.reflectScrolledClipView(columns.contentView)
            #expect(waitForStableRender(hosted.hosting))
            let hidden = try #require(frames.inMonth[today])
            try #require(hidden.maxX <= 0 || hidden.minX >= size.width)

            model.goToToday()
            #expect(waitForStableRender(hosted.hosting))
            let revealed = try #require(frames.inMonth[today])
            #expect(revealed.minX >= 0 && revealed.maxX <= size.width)
            #expect(calendar.isDate(model.currentDate, inSameDayAs: now))
        }

        let previous = try #require(calendar.date(byAdding: .month, value: -8, to: now))
        try model.navigate(to: previous)
        #expect(waitForStableRender(hosted.hosting))
        model.goToToday()
        #expect(waitForStableRender(hosted.hosting))
        let restored = try #require(frames.inMonth[today])
        #expect(restored.minX >= 0 && restored.maxX <= size.width)
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let current = (view as? NSScrollView).map { [$0] } ?? []
        return current + view.subviews.flatMap { scrollViews(in: $0) }
    }
}
#endif
