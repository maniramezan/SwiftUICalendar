#if os(macOS)
import AppKit
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Short calendar viewports", .serialized)
struct CalendarShortViewportTests {
    @Test(
        "The last row stays reachable after a live height reduction",
        arguments: [CalendarConfiguration.ScrollMode.none, .horizontal],
        [Calendar.Identifier.gregorian, .persian])
    func lastRowReachableAfterResize(
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) throws {
        let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
        model.select(model.currentDate)
        let selection = model.selection
        let month = model.visibleMonth
        let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let tall = CGSize(width: 600, height: 800)
        let short = CGSize(width: 600, height: 240)
        let hosted = hostView(
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
            size: tall)
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        expectNonBlankRender(hosted.hosting, size: tall, "tall \(mode)")

        hosted.hosting.frame = CGRect(origin: .zero, size: short)
        #expect(waitForStableRender(hosted.hosting))
        expectNonBlankRender(hosted.hosting, size: short, "short \(mode)")

        // The outer viewport scrolls columns; a distinct inner viewport must scroll rows.
        let scrolls = scrollViews(in: hosted.hosting)
        #expect(scrolls.count >= 2, "\(mode) needs a vertical overflow fallback")
        let rows = try #require(scrolls.last)
        let document = try #require(rows.documentView)
        #expect(document.frame.height > rows.contentView.bounds.height)
        #expect(rows.contentView.bounds.height <= short.height)

        // Scroll to the bottom and prove the final row lies in the visible document region.
        let bottom = max(0, document.frame.height - rows.contentView.bounds.height)
        rows.contentView.scroll(to: CGPoint(x: 0, y: bottom))
        rows.reflectScrolledClipView(rows.contentView)
        #expect(waitForStableRender(hosted.hosting))
        #expect(abs(rows.documentVisibleRect.maxY - document.frame.maxY) < 1)
        #expect(model.visibleMonth == month, "overflow scrolling must not navigate months")
        #expect(model.selection == selection, "resizing must preserve the selected date")
        #expect(frames.inMonth.count >= 28)
        for frame in frames.inMonth.values {
            #expect(frame.height >= CalendarMetrics.default.minCellSize)
        }

        hosted.hosting.frame = CGRect(origin: .zero, size: tall)
        #expect(waitForStableRender(hosted.hosting))
        #expect(document.frame.height <= rows.contentView.bounds.height)
        #expect(model.visibleMonth == month)
        #expect(model.selection == selection)
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let current = (view as? NSScrollView).map { [$0] } ?? []
        return current + view.subviews.flatMap { scrollViews(in: $0) }
    }
}
#endif
