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

    @Test("Soft margins give way before the grid overflows")
    func softMarginsCollapseFirst() {
        // 370pt fits the 356pt grid, just not its 52pt of margins: no scrolling, margins shrink.
        let squeezed = CalendarViewportLayout(width: 370, minimumWidth: 356, margins: 52)
        #expect(!squeezed.overflows)
        #expect(squeezed.contentWidth == 370)
    }

    @Test("An overflowing grid carries its full margins so the outer columns stay reachable")
    func overflowRestoresMargins() {
        let narrow = CalendarViewportLayout(width: 320, minimumWidth: 356, margins: 52)
        #expect(narrow.overflows)
        // Typed explicitly: `#expect` evaluates each operand on its own, so a bare `356 + 52` is
        // inferred as `Int` and compares unequal to the `CGFloat` 408 it matches.
        #expect(narrow.contentWidth == CGFloat(356 + 52))
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

        private func mountMeasured(
            mode: CalendarConfiguration.ScrollMode, width: CGFloat
        ) throws -> (frames: MeasuredDayFrames, dispose: () -> Void) {
            let model = CalendarViewModel.snapshot(selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let size = CGSize(width: width, height: 800)
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
                size: size)
            #expect(waitForStableRender(hosted.hosting))
            expectNonBlankRender(hosted.hosting, size: size, "\(mode) at width \(width)")
            return (frames, { hosted.window.contentView = nil })
        }

        /// The vertical body once required 356 + 2 × 16 = 388pt before the viewport, measured
        /// against the unpadded width and then padded again inside, so on a 375pt phone the last
        /// column ran past the screen edge and only appeared after a sideways scroll. Every phone
        /// width must show the whole month with nothing to scroll.
        @Test(
            "Phone-width calendars show every day without scrolling",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [375.0, 393.0, 402.0])
        func phoneWidthsFit(mode: CalendarConfiguration.ScrollMode, width: CGFloat) throws {
            let mounted = try mountMeasured(mode: mode, width: width)
            defer { mounted.dispose() }
            #expect(mounted.frames.inMonth.count >= 28)
            for frame in mounted.frames.inMonth.values {
                #expect(
                    frame.minX >= -0.5 && frame.maxX <= width + 0.5,
                    "\(mode) at \(width): a day cell at \(frame) is off screen")
            }
            let widest = try #require(mounted.frames.widestCell)
            #expect(widest >= CalendarMetrics.default.minCellSize)
        }

        /// The fixed calendar lost its side margins when it moved inside the viewport: its grid ran
        /// edge to edge because the scroll view absorbed the margin that used to inset it.
        @Test("The fixed calendar keeps its margin", arguments: [393.0, 600.0])
        func fixedCalendarKeepsMargin(width: CGFloat) throws {
            let mounted = try mountMeasured(mode: .none, width: width)
            defer { mounted.dispose() }
            let margin = CalendarMetrics.default.calendarMargin
            let minX = try #require(mounted.frames.inMonth.values.map(\.minX).min())
            let maxX = try #require(mounted.frames.inMonth.values.map(\.maxX).max())
            #expect(minX >= margin - 0.5, "leading margin lost at \(width): grid starts at \(minX)")
            #expect(
                maxX <= width - margin + 0.5,
                "trailing margin lost at \(width): grid ends at \(maxX)")
        }

        /// Before the viewport, a 320pt window centered an overflowing grid and pushed its first
        /// column past the leading edge where no scroll could reach it. Overflow must start at the
        /// leading edge so every column is reachable.
        @Test(
            "An overflowing calendar starts with its first column on screen",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ])
        func overflowStartsAtLeadingEdge(mode: CalendarConfiguration.ScrollMode) throws {
            let mounted = try mountMeasured(mode: mode, width: 320)
            defer { mounted.dispose() }
            let minX = try #require(mounted.frames.inMonth.values.map(\.minX).min())
            #expect(minX >= 0, "\(mode): the first column starts off screen at \(minX)")
        }
    #endif
}
