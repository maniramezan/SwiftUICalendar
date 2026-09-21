import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Calendar viewport")
struct CalendarViewportTests {
    @Test("Narrow windows preserve the minimum width", arguments: [0.0, 240.0, 320.0])
    func narrow(width: CGFloat) {
        let layout = CalendarViewportLayout(width: width, minimumWidth: 356)
        #expect(layout.contentWidth == 356)
        #expect(layout.overflows)
    }

    @Test("Fitting windows do not overflow", arguments: [356.0, 600.0, 1024.0])
    func fitting(width: CGFloat) {
        let layout = CalendarViewportLayout(width: width, minimumWidth: 356)
        #expect(layout.contentWidth == width)
        #expect(!layout.overflows)
    }

    #if os(macOS)
        @Test("Narrow viewport exposes horizontal scrolling and preserves content height")
        func hostedOverflow() throws {
            let hosted = hostView(
                CalendarViewport { _ in
                    HStack {
                        Text("First day")
                        Spacer()
                        Text("Last day")
                    }
                    .frame(height: 400)
                }, size: CGSize(width: 240, height: 500))
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            #expect(hosted.hosting.fittingSize.height >= 400)
        }

        /// The viewport resolves its content width during layout rather than through `@State`, so the
        /// first pass is already final. When it did read the width into state, the vertical body laid
        /// out once at a placeholder width and the `LazyVStack` inside could settle with no realized
        /// rows, leaving a blank calendar. Assert real day cells at both sides of the overflow
        /// boundary, in every scroll mode.
        @Test(
            "A mounted calendar lays out day cells on both sides of the overflow boundary",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [260.0, 900.0])
        func mountedCalendarRealizesDays(
            mode: CalendarConfiguration.ScrollMode, width: CGFloat
        ) throws {
            let model = CalendarViewModel.snapshot(selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let size = CGSize(width: width, height: 900)
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
                size: size)
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            expectNonBlankRender(hosted.hosting, size: size, "\(mode) at width \(width)")
            #expect(
                frames.inMonth.count >= 28,
                "\(mode) at width \(width) laid out only \(frames.inMonth.count) day cells")
            // Overflowing horizontally is what buys the minimum touch target back, so it must hold
            // on the narrow side of the boundary too.
            let widest = try #require(frames.widestCell)
            #expect(widest >= CalendarMetrics.default.minCellSize)
        }
    #endif
}
