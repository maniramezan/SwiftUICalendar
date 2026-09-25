import SwiftUI
import Testing

@testable import SwiftUICalendar

/// `ReservedRegion` has no public initializer, so the fold geometry is exercised through plain
/// ranges. The thin adapter that turns real division regions into those ranges is the only part that
/// needs a folded device.
@Suite("Calendar fold span")
struct CalendarFoldSpanTests {
    @Test("No blocked ranges leaves the container whole")
    func noFold() {
        #expect(CalendarFoldSpan.resolve(containerWidth: 780, blocked: []) == .none)
        #expect(CalendarFoldSpan.none.total == 0)
    }

    @Test("A zero-width container resolves to no fold")
    func emptyContainer() {
        #expect(CalendarFoldSpan.resolve(containerWidth: 0, blocked: [380...400]) == .none)
    }

    @Test("A fold past the middle displaces to the wider leading band")
    func foldPastMiddlePrefersLeadingBand() {
        // Bands are 0..<400 (400pt) and 460..<780 (320pt), so the leading one wins outright.
        // `trailing` is the inset from the trailing edge, so it covers the block and the 320pt band.
        let span = CalendarFoldSpan.resolve(containerWidth: 780, blocked: [400...460])
        #expect(span.leading == 0)
        #expect(span.trailing == 380)
        #expect(780 - span.total == 400)
    }

    @Test("A fold nearer the leading edge displaces to the trailing band")
    func foldNearLeadingEdge() {
        let span = CalendarFoldSpan.resolve(containerWidth: 780, blocked: [200...240])
        #expect(span.leading == 240)
        #expect(span.trailing == 0)
        #expect(780 - span.total == 540)
    }

    @Test("Insets and the chosen band always add back up to the container")
    func spanPartitionsContainer() {
        for hinge in stride(from: 40.0, through: 740.0, by: 50.0) {
            let width = 780.0
            let span = CalendarFoldSpan.resolve(
                containerWidth: width, blocked: [hinge...(hinge + 30)])
            let band = width - span.total
            #expect(span.leading >= 0)
            #expect(span.trailing >= 0)
            #expect(band > 0, "a fold at \(hinge) left no usable band")
            #expect(span.leading + band + span.trailing == width)
        }
    }

    @Test("Overlapping ranges merge before the widest band is chosen")
    func overlappingRangesMerge() {
        // The two overlapping bands behave as one 300...500 block, so the free bands are 0..<300
        // (300pt) and 500..<780 (280pt) and the leading one wins on width.
        let span = CalendarFoldSpan.resolve(
            containerWidth: 780, blocked: [300...400, 380...500])
        #expect(span.leading == 0)
        #expect(span.trailing == 480)
        #expect(780 - span.total == 300)
    }

    /// Equally wide bands resolve to the leading one. Arbitrary but deterministic: without a
    /// tie-break a symmetrically folded device could flip the calendar side to side.
    @Test("Equally wide bands resolve to the leading one")
    func tieBreaksTowardLeading() {
        let span = CalendarFoldSpan.resolve(containerWidth: 780, blocked: [300...480])
        #expect(780 - span.total == 300)
        #expect(span.leading == 0)
        #expect(span.trailing == 480)
    }

    @Test("Ranges are clamped to the container and misses are ignored")
    func rangesAreClamped() {
        // Entirely outside the container.
        #expect(CalendarFoldSpan.resolve(containerWidth: 400, blocked: [500...600]) == .none)
        // Overhangs the trailing edge, so only the leading band survives.
        let span = CalendarFoldSpan.resolve(containerWidth: 400, blocked: [300...900])
        #expect(span.leading == 0)
        #expect(400 - span.total == 300)
    }

    @Test("A fold covering the container leaves it whole rather than rendering nothing")
    func fullyBlockedContainerFallsBack() {
        #expect(CalendarFoldSpan.resolve(containerWidth: 400, blocked: [-10...410]) == .none)
        #expect(CalendarFoldSpan.resolve(containerWidth: 400, blocked: [0...400]) == .none)
    }

    // MARK: - Layout direction

    @Test("Left-to-right fold ranges are already leading-origin")
    func leftToRightRangesUnchanged() {
        let ranges: [ClosedRange<CGFloat>] = [520...580]
        #expect(
            CalendarFoldSpan.leadingOrigin(
                ranges, containerWidth: 900, layoutDirection: .leftToRight)
                == ranges)
    }

    @Test("Right-to-left fold ranges are measured from the right edge")
    func rightToLeftRangesMirror() {
        let mirrored = CalendarFoldSpan.leadingOrigin(
            [520...580, 0...10], containerWidth: 900, layoutDirection: .rightToLeft)
        #expect(mirrored == [320...380, 890...900])
    }

    /// Same physical fold, same physical outcome: the grid lands in the wider band to the fold's left
    /// whichever way the calendar reads.
    @Test("A right-to-left calendar picks the same physical band")
    func rightToLeftPicksSamePhysicalBand() {
        let physical: [ClosedRange<CGFloat>] = [520...580]
        let span = CalendarFoldSpan.resolve(
            containerWidth: 900,
            blocked: CalendarFoldSpan.leadingOrigin(
                physical, containerWidth: 900, layoutDirection: .rightToLeft))
        // Right-to-left, the leading edge is the physical right. The widest free band starts 380pt
        // from it and runs to the far edge: physically 0..520.
        #expect(span.leading == 380)
        #expect(span.trailing == 0)
    }

    /// The viewport subtracts `total` before deciding whether the grid overflows, so a fold that
    /// squeezes the band below the minimum width has to trip overflow scrolling.
    @Test("A narrow band below the minimum width overflows the viewport")
    func narrowBandOverflows() {
        let metrics = CalendarMetrics.default
        let container = 700.0
        // Hinge close to the trailing edge: widest band is 0..<300, under the 356pt minimum.
        let span = CalendarFoldSpan.resolve(containerWidth: container, blocked: [300...700])
        let band = container - span.total
        #expect(band == 300)

        let layout = CalendarViewportLayout(width: band, minimumWidth: metrics.minCalendarWidth)
        #expect(layout.overflows)
        #expect(layout.contentWidth == metrics.minCalendarWidth)

        // Without the fold the same container comfortably fits.
        #expect(
            !CalendarViewportLayout(width: container, minimumWidth: metrics.minCalendarWidth)
                .overflows)
    }
}

#if os(macOS)
    import AppKit

    /// Hosted coverage for the displacement itself, not just the band arithmetic. This is only
    /// reachable because the fold source is injected: were the hinge read from
    /// `GeometryProxy.reservedRegions`, no test could produce one.
    @MainActor
    @Suite("Calendar fold displacement", .serialized)
    struct CalendarFoldDisplacementTests {
        private static let size = CGSize(width: 900, height: 800)

        /// Right-to-left calendars flip leading and trailing padding, which once put the Persian
        /// grid at 382–878 — straight across a fold at 520–580 that the Gregorian grid cleared.
        @Test(
            "Day cells keep clear of a blocked band",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [Calendar.Identifier.gregorian, .persian, .hebrew])
        func daysAvoidTheBand(
            mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
        ) throws {
            // Hinge past the middle, so the grid belongs in the wider band to its left.
            let blocked: ClosedRange<CGFloat> = 520...580
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode))
                    .environment(\.calendarFoldRanges, [blocked]),
                size: Self.size)
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            expectNonBlankRender(hosted.hosting, size: Self.size, "folded \(mode)")
            #expect(frames.inMonth.count >= 28)

            for (date, frame) in frames.inMonth {
                let intersects = frame.maxX > blocked.lowerBound && frame.minX < blocked.upperBound
                #expect(
                    !intersects,
                    "a day cell overlapped the fold in \(mode) mode: \(frame) vs \(blocked) (\(date))"
                )
            }
            // Cells must not have been shrunk below the touch floor to fit beside the fold.
            let widest = try #require(frames.widestCell)
            #expect(widest >= CalendarMetrics.default.minCellSize)
        }

        /// Proves the displacement actually moved something: at this container width the grid is
        /// already at its capped natural width, so an unfolded calendar centers it straight across
        /// the band the hinge would occupy. Folded, the same grid has to clear that band entirely.
        @Test(
            "Displacement moves a grid that would otherwise cross the fold",
            arguments: [Calendar.Identifier.gregorian, .persian])
        func displacementMovesTheGrid(identifier: Calendar.Identifier) throws {
            let blocked: ClosedRange<CGFloat> = 520...580
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let month = try #require(model.monthIdentifier())

            func bounds(foldRanges: [ClosedRange<CGFloat>]) throws -> (
                minX: CGFloat, maxX: CGFloat
            ) {
                let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
                let theme = Theme()
                theme.day.setDayContent { context in
                    MeasuringDayView(context: context, frames: frames)
                }
                let hosted = hostView(
                    CalendarView(model: model, theme: theme, configuration: .init())
                        .environment(\.calendarFoldRanges, foldRanges),
                    size: Self.size)
                defer { hosted.window.contentView = nil }
                #expect(waitForStableRender(hosted.hosting))
                let minX = try #require(frames.inMonth.values.map(\.minX).min())
                let maxX = try #require(frames.inMonth.values.map(\.maxX).max())
                return (minX, maxX)
            }

            let unfolded = try bounds(foldRanges: [])
            #expect(
                unfolded.maxX > blocked.lowerBound && unfolded.minX < blocked.upperBound,
                "\(identifier): the unfolded grid must cross the band, or this proves nothing")

            let folded = try bounds(foldRanges: [blocked])
            #expect(
                folded.maxX <= blocked.lowerBound,
                "\(identifier): the folded grid must clear the band")
            #expect(
                folded.minX < unfolded.minX,
                "\(identifier): the folded grid must have moved into the wider band")
            // Same grid, just relocated: displacement must not resize it.
            #expect(abs((folded.maxX - folded.minX) - (unfolded.maxX - unfolded.minX)) < 0.5)
        }
    }
#endif
