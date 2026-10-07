#if os(macOS)
import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Unbounded calendar host", .serialized)
struct CalendarUnboundedHostTests {
    @Test func calendarInsideHostScrollViewHasVisibleRows() throws {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let frames = MeasuredDayFrames(
            month: try #require(model.monthIdentifier()), calendar: model.engine.calendar)
        let theme = Theme()
        theme.day.setDayContent { MeasuringDayView(context: $0, frames: frames) }
        let hosted = hostView(
            ScrollView { CalendarView(model: model, theme: theme) },
            size: CGSize(width: 375, height: 700))
        defer { hosted.window.contentView = nil }
        #expect(waitForStableRender(hosted.hosting))
        #expect(frames.inMonth.count >= 28)
        // Presence in the accessibility tree alone does not prove any row is painted.
        let visible = frames.inMonth.values.filter { $0.minY >= 0 && $0.maxY <= 700 }
        #expect(visible.count >= 7)
        #expect(visible.allSatisfy { $0.height >= 44 })
    }
}
#endif
