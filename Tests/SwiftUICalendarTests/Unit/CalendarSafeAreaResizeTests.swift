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
            let frames = DayFrames(month: originalMonth, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                FrameDay(context: context, frames: frames)
            }
            let hosted = hostView(
                InsetCalendar(model: model, theme: theme, mode: mode, insets: insets),
                size: CGSize(width: 1000, height: 900))
            defer { hosted.window.contentView = nil }
            for (width, leading, trailing) in [
                (1000.0, 120.0, 16.0), (700.0, 16.0, 120.0), (600.0, 24.0, 64.0),
            ] {
                insets.value = EdgeInsets(top: 0, leading: leading, bottom: 0, trailing: trailing)
                hosted.window.setContentSize(CGSize(width: width, height: 900))
                #expect(waitForStableRender(hosted.hosting))
                #expect(model.visibleMonth == originalMonth)
                #expect(model.selection == originalSelection)
                #expect(frames.values.count >= 28)
                for frame in frames.values.values {
                    #expect(frame.minX >= leading)
                    #expect(frame.maxX <= width - trailing)
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

    @MainActor
    private final class DayFrames {
        let month: MonthIdentifier
        let calendar: Calendar
        var values: [Date: CGRect] = [:]

        init(month: MonthIdentifier, calendar: Calendar) {
            self.month = month
            self.calendar = calendar
        }
    }

    private struct FrameDay: CalendarDayView {
        let context: CalendarDayContext
        var frames: DayFrames?

        init(context: CalendarDayContext) {
            self.context = context
        }

        init(context: CalendarDayContext, frames: DayFrames) {
            self.context = context
            self.frames = frames
        }

        var body: some View {
            Text(context.dayLabel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .global)
                } action: { frame in
                    if context.isInCurrentMonth, let frames,
                        CalendarEngine(calendar: frames.calendar).month(containing: context.date)
                            == frames.month
                    {
                        frames.values[context.date] = frame
                    }
                }
        }
    }
#endif
