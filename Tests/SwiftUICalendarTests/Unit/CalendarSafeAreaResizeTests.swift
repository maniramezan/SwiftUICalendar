#if os(macOS)
    import AppKit
    import SwiftUI
    import Testing

    @testable import SwiftUICalendar

    @MainActor
    @Suite("Calendar asymmetric safe areas", .serialized)
    struct CalendarSafeAreaResizeTests {
        @Test(
            "Live inset changes keep days inside the available area",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [Calendar.Identifier.gregorian, .persian])
        func asymmetricInsets(
            mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
        ) throws {
            let model = CalendarViewModel.snapshot(identifier: identifier)
            model.select(model.currentDate)
            let originalMonth = model.visibleMonth
            let originalSelection = model.selection
            let insets = ResizeInsets()
            let month = try #require(model.monthIdentifier())
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let hosted = hostView(
                InsetCalendar(model: model, theme: theme, mode: mode, insets: insets),
                size: CGSize(width: 1000, height: 900))
            defer { hosted.window.contentView = nil }
            for (width, leading, trailing) in [
                (1000.0, 120.0, 16.0), (700.0, 16.0, 120.0), (600.0, 24.0, 64.0),
            ] {
                let size = CGSize(width: width, height: 900)
                insets.value = EdgeInsets(top: 0, leading: leading, bottom: 0, trailing: trailing)
                hosted.window.setContentSize(size)
                #expect(waitForStableRender(hosted.hosting))
                // A calendar that laid out no cells stabilizes as a blank frame, which would
                // otherwise surface only as the day count below.
                expectNonBlankRender(
                    hosted.hosting, size: size,
                    "\(mode)/\(identifier) at \(width) with insets \(leading)/\(trailing)")
                #expect(model.visibleMonth == originalMonth)
                #expect(model.selection == originalSelection)
                #expect(frames.inMonth.count >= 28)
                // Clear of the inset *and* the calendar's own margin: checking the inset alone let a
                // grid that had lost its margins, running edge to edge, pass.
                let margin = CalendarMetrics.default.calendarMargin
                for frame in frames.inMonth.values {
                    #expect(frame.minX >= leading + margin - 0.5)
                    #expect(frame.maxX <= width - trailing - margin + 0.5)
                    #expect(frame.width >= CalendarMetrics.default.minCellSize)
                }
            }
        }
    }

    @MainActor
    @Observable
    private final class ResizeInsets {
        var value = EdgeInsets()
    }

    private struct InsetCalendar: View {
        let model: CalendarViewModel
        let theme: Theme
        let mode: CalendarConfiguration.ScrollMode
        let insets: ResizeInsets

        var body: some View {
            CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                .safeAreaPadding(insets.value)
        }
    }
#endif
