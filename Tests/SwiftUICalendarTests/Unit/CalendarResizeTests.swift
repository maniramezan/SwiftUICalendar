#if os(macOS)
    import AppKit
    import SwiftUI
    import Testing

    @testable import SwiftUICalendar

    @MainActor
    @Suite("Calendar resizing", .serialized)
    struct CalendarResizeTests {
        private static let height: CGFloat = 900

        @Test(
            "Resizing preserves day state and navigation",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [Calendar.Identifier.gregorian, .persian])
        func preservesIdentity(
            mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
        ) throws {
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let month = model.visibleMonth
            let identities = ResizeIdentities(date: model.currentDate)
            let theme = Theme()
            theme.day.setDayContent { context in
                ResizeDay(context: context, identities: identities)
            }
            let initialSize = CGSize(width: 600, height: Self.height)
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
                size: initialSize)
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            // A calendar that laid out no day cells stabilizes as a blank frame, which would
            // otherwise surface only as the empty `original` below.
            expectNonBlankRender(
                hosted.hosting, size: initialSize, "\(mode)/\(identifier) at mount")
            let original = identities.values
            #expect(!original.isEmpty)
            for width in [599.0, 800.0, 450.0, 600.0] {
                let size = CGSize(width: width, height: Self.height)
                hosted.window.setContentSize(size)
                #expect(waitForStableRender(hosted.hosting))
                expectNonBlankRender(
                    hosted.hosting, size: size, "\(mode)/\(identifier) at width \(width)")
                #expect(model.visibleMonth == month)
                for (date, identity) in original {
                    #expect(identities.values[date] == identity)
                }
            }
        }

        /// Removing the width-keyed `.id(_:)` reset from `CalendarView` is what lets the day cells
        /// above keep their `@State` across a resize. That reset also had a second effect: it forced
        /// every body mode to re-measure from scratch, papering over a grid still sized for the
        /// previous width. Nothing else replaced that, so assert it directly — a calendar resized to
        /// a width must resolve the same day geometry as one mounted at that width from the start.
        @Test(
            "Resizing re-resolves the grid for the new width",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [Calendar.Identifier.gregorian, .persian])
        func resizeReresolvesGrid(
            mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
        ) throws {
            // Mounted narrow, then widened: the live rotation/resize path.
            let resizedFrames = MeasuredDayFrames()
            let resized = mountMeasuredCalendar(
                mode: mode, identifier: identifier, frames: resizedFrames,
                size: CGSize(width: 430, height: Self.height))
            defer { resized.window.contentView = nil }
            #expect(waitForStableRender(resized.hosting))
            let narrowCell = try #require(resizedFrames.widestCell)
            let narrowSpan = try #require(resizedFrames.span)

            let target = CGSize(width: 920, height: Self.height)
            resizedFrames.reset()
            resized.window.setContentSize(target)
            #expect(waitForStableRender(resized.hosting))
            expectNonBlankRender(
                resized.hosting, size: target, "resized \(mode)/\(identifier)")

            // Mounted at the target width from the start: the reference geometry.
            let freshFrames = MeasuredDayFrames()
            let fresh = mountMeasuredCalendar(
                mode: mode, identifier: identifier, frames: freshFrames, size: target)
            defer { fresh.window.contentView = nil }
            #expect(waitForStableRender(fresh.hosting))
            expectNonBlankRender(fresh.hosting, size: target, "fresh \(mode)/\(identifier)")

            let resizedCell = try #require(resizedFrames.widestCell)
            let freshCell = try #require(freshFrames.widestCell)
            #expect(
                resizedCell == freshCell,
                "resized grid kept a cell size of \(resizedCell) where a fresh mount resolves \(freshCell)"
            )
            let resizedSpan = try #require(resizedFrames.span)
            let freshSpan = try #require(freshFrames.span)
            #expect(
                resizedSpan == freshSpan,
                "resized grid spans \(resizedSpan) where a fresh mount spans \(freshSpan)")
            // Guards the assertions above against passing vacuously: the two widths have to resolve
            // different geometry, or "resized matches fresh" would hold no matter what.
            #expect(
                resizedCell != narrowCell || resizedSpan != narrowSpan,
                "width 430 and 920 resolved identical geometry, so this test proves nothing")
        }

        private func mountMeasuredCalendar(
            mode: CalendarConfiguration.ScrollMode,
            identifier: Calendar.Identifier,
            frames: MeasuredDayFrames,
            size: CGSize
        ) -> (window: NSWindow, hosting: NSHostingView<CalendarView>) {
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            return hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
                size: size)
        }
    }

    @MainActor
    private final class ResizeIdentities {
        let date: Date
        var values: [Date: UUID] = [:]

        init(date: Date) { self.date = date }
    }

    private struct ResizeDay: CalendarDayView {
        let context: CalendarDayContext
        var identities: ResizeIdentities?
        @State private var identity = UUID()

        init(context: CalendarDayContext) {
            self.context = context
        }

        init(context: CalendarDayContext, identities: ResizeIdentities) {
            self.context = context
            self.identities = identities
        }

        var body: some View {
            Text(context.dayLabel)
                .onAppear {
                    if context.isInCurrentMonth,
                        let identities,
                        context.calendar.isDate(context.date, inSameDayAs: identities.date)
                    {
                        identities.values[context.date] = identity
                    }
                }
        }
    }
#endif
