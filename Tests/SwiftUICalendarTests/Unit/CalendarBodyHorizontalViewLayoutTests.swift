import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyHorizontalView Layout Tests")
struct CalendarBodyHorizontalViewLayoutTests {

    /// The layout helpers are now `CalendarMetrics` methods, so a test pins a width against one
    /// metrics instance instead of threading a scalar list per call.
    private let metrics = CalendarMetrics.default

    @Test("layoutWidth respects the minimum calendar width")
    func layoutWidthRespectsMinimumCalendarWidth() {
        #expect(metrics.layoutWidth(containerWidth: 320) == 356)
        #expect(metrics.layoutWidth(containerWidth: 390) == 390)
    }

    @Test("carousel peek reaches past the centered cell's margin into real content")
    func carouselReservesAvailableWidthForPeeks() {
        #expect(metrics.peekWidth(containerWidth: 390) == 17)
        #expect(metrics.pageWidth(containerWidth: 390) == 356)
        #expect(metrics.peekWidth(containerWidth: 356) == 0)
        #expect(metrics.pageWidth(containerWidth: 356) == 356)
    }

    @Test("carousel track exposes the parked months on mirrored RTL edges")
    func carouselTrackMirrorsPeekedMonthsInRTL() {
        let peekWidth = metrics.peekWidth(containerWidth: 390)
        let pageWidth = metrics.pageWidth(containerWidth: 390)

        let ltrPrevious =
            CalendarBodyHorizontalView.previousMonthBaseOffset(
                layoutWidth: pageWidth,
                layoutDirectionMultiplier: 1
            ) + peekWidth
        let ltrNext =
            CalendarBodyHorizontalView.nextMonthBaseOffset(
                layoutWidth: pageWidth,
                layoutDirectionMultiplier: 1
            ) + peekWidth
        let rtlPrevious =
            CalendarBodyHorizontalView.previousMonthBaseOffset(
                layoutWidth: pageWidth,
                layoutDirectionMultiplier: -1
            ) + peekWidth
        let rtlNext =
            CalendarBodyHorizontalView.nextMonthBaseOffset(
                layoutWidth: pageWidth,
                layoutDirectionMultiplier: -1
            ) + peekWidth

        #expect(ltrPrevious == -339)
        #expect(ltrNext == 373)
        #expect(rtlPrevious == 373)
        #expect(rtlNext == -339)
    }

    @Test("cellSize clamps between minimum and maximum bounds")
    func cellSizeClampsBetweenBounds() {
        #expect(
            CalendarGridLayout.cellSize(containerWidth: 320, metrics: metrics)
                == metrics.minCellSize)
        #expect(
            CalendarGridLayout.cellSize(containerWidth: 600, metrics: metrics)
                == metrics.maxCellSize)
    }

    @Test("cellSize interpolates between bounds for mid-range widths")
    func cellSizeInterpolatesBetweenBounds() {
        // widthForCells = 400 - (8 * 6) = 352; columnWidth = 352 / 7 ≈ 50.29 → between 44 and 64.
        let size = CalendarGridLayout.cellSize(containerWidth: 400, metrics: metrics)

        #expect(size > metrics.minCellSize)
        #expect(size < metrics.maxCellSize)
        #expect(
            abs(size - (400 - metrics.itemSpacing * 6) / 7) < 0.0001)
    }

    @Test("rowCount hugs the tallest parked month and pins to six rows otherwise")
    func rowCountResolvesHeightMode() {
        #expect(
            CalendarBodyHorizontalView.rowCount(
                mode: .hugContent, currentRows: 5, previousRows: 6, nextRows: 4
            ) == 6
        )
        #expect(
            CalendarBodyHorizontalView.rowCount(
                mode: .hugContent, currentRows: 4, previousRows: 4, nextRows: 5
            ) == 5
        )
        #expect(
            CalendarBodyHorizontalView.rowCount(
                mode: .sixRows, currentRows: 4, previousRows: 4, nextRows: 4
            ) == 6
        )
    }

    @Test("weekdayHeaderHeight keeps the minimum header height")
    func weekdayHeaderHeightKeepsMinimum() {
        #expect(metrics.weekdayHeaderHeight(cellSize: 44) == 24)
        #expect(metrics.weekdayHeaderHeight(cellSize: 64) == 28.8)
    }

    @Test("month offsets mirror the layout direction multiplier")
    func monthOffsetsMirrorLayoutDirectionMultiplier() {
        #expect(
            CalendarBodyHorizontalView.previousMonthBaseOffset(
                layoutWidth: 390,
                layoutDirectionMultiplier: 1
            ) == -390
        )
        #expect(
            CalendarBodyHorizontalView.nextMonthBaseOffset(
                layoutWidth: 390,
                layoutDirectionMultiplier: 1
            ) == 390
        )
        #expect(
            CalendarBodyHorizontalView.previousMonthBaseOffset(
                layoutWidth: 390,
                layoutDirectionMultiplier: -1
            ) == 390
        )
        #expect(
            CalendarBodyHorizontalView.nextMonthBaseOffset(
                layoutWidth: 390,
                layoutDirectionMultiplier: -1
            ) == -390
        )
    }

    @Test("resolvedHeight includes row spacing and ceiling padding")
    func resolvedHeightIncludesSpacingAndPadding() {
        let height = metrics.resolvedHeight(rowCount: 6, layoutWidth: 390)

        #expect(height == 336)
    }

    @Test("swipeThreshold respects the minimum threshold floor")
    func swipeThresholdRespectsMinimumFloor() {
        #expect(metrics.pager.swipeThreshold(layoutWidth: 120) == 56)
        #expect(metrics.pager.swipeThreshold(layoutWidth: 400) == 100)
    }

    @Test("nextDragOffset ignores updates during navigation")
    func nextDragOffsetIgnoresUpdatesDuringNavigation() {
        #expect(
            CalendarBodyHorizontalView.nextDragOffset(
                currentDragOffset: 12,
                translationWidth: 80,
                limit: 390,
                isNavigating: true
            ) == 12
        )
        #expect(
            CalendarBodyHorizontalView.nextDragOffset(
                currentDragOffset: 12,
                translationWidth: 80,
                limit: 390,
                isNavigating: false
            ) == 80
        )
    }

    @Test("resolvedMonthDelta honors swipe semantics for both directions")
    func resolvedMonthDeltaHonorsSwipeSemantics() {
        #expect(
            CalendarBodyHorizontalView.resolvedMonthDelta(
                translationWidth: -40,
                predictedEndTranslationWidth: -220,
                layoutDirectionMultiplier: 1,
                layoutWidth: 390,
                pager: metrics.pager
            ) == 1
        )
        #expect(
            CalendarBodyHorizontalView.resolvedMonthDelta(
                translationWidth: 40,
                predictedEndTranslationWidth: 220,
                layoutDirectionMultiplier: 1,
                layoutWidth: 390,
                pager: metrics.pager
            ) == -1
        )
        #expect(
            CalendarBodyHorizontalView.resolvedMonthDelta(
                translationWidth: 10,
                predictedEndTranslationWidth: 20,
                layoutDirectionMultiplier: 1,
                layoutWidth: 390,
                pager: metrics.pager
            ) == nil
        )
    }

    @Test("resolvedMonthDelta inverts physical swipe direction in RTL layouts")
    func resolvedMonthDeltaInvertsForRTL() {
        // RTL (multiplier -1): a physical left swipe (negative translation) should go to the
        // previous month, mirroring the LTR-next case above.
        #expect(
            CalendarBodyHorizontalView.resolvedMonthDelta(
                translationWidth: -40,
                predictedEndTranslationWidth: -220,
                layoutDirectionMultiplier: -1,
                layoutWidth: 390,
                pager: metrics.pager
            ) == -1
        )
        #expect(
            CalendarBodyHorizontalView.resolvedMonthDelta(
                translationWidth: 40,
                predictedEndTranslationWidth: 220,
                layoutDirectionMultiplier: -1,
                layoutWidth: 390,
                pager: metrics.pager
            ) == 1
        )
    }

    @Test("pagerAction maps month deltas to pager actions")
    func pagerActionMapsMonthDeltas() {
        #expect(CalendarBodyHorizontalView.pagerAction(for: 1) == .next)
        #expect(CalendarBodyHorizontalView.pagerAction(for: -1) == .previous)
        #expect(CalendarBodyHorizontalView.pagerAction(for: nil) == .snapBack)
        #expect(CalendarBodyHorizontalView.pagerAction(for: 0) == .snapBack)
    }

    @Test("offset helpers move in opposite directions")
    func offsetHelpersMoveInOppositeDirections() {
        #expect(
            CalendarBodyHorizontalView.nextOffset(
                currentOffset: 10,
                width: 390,
                layoutDirectionMultiplier: 1
            ) == -380
        )
        #expect(
            CalendarBodyHorizontalView.previousOffset(
                currentOffset: 10,
                width: 390,
                layoutDirectionMultiplier: 1
            ) == 400
        )
    }

    @Test("shouldHandleScrollPage only accepts next and previous deltas when idle")
    func shouldHandleScrollPageOnlyAcceptsPagingDeltasWhenIdle() {
        #expect(CalendarBodyHorizontalView.shouldHandleScrollPage(delta: 1, isNavigating: false))
        #expect(CalendarBodyHorizontalView.shouldHandleScrollPage(delta: -1, isNavigating: false))
        #expect(!CalendarBodyHorizontalView.shouldHandleScrollPage(delta: 0, isNavigating: false))
        #expect(!CalendarBodyHorizontalView.shouldHandleScrollPage(delta: 1, isNavigating: true))
    }

    #if os(macOS)
    @Test(
        "horizontal calendar renders identically to a fresh portrait view after rotating from landscape"
    )
    func horizontalCalendarMatchesFreshPortraitAfterRotation() throws {
        // Reference: a calendar created directly at the portrait size.
        let freshViewModel = CalendarViewModel.snapshot(selection: .single(nil))
        let freshView = CalendarView(
            model: freshViewModel,
            configuration: CalendarConfiguration(scrollMode: .horizontal)
        )
        let portraitSize = CGSize(width: 390, height: 844)
        let freshHosted = hostView(freshView, size: portraitSize)
        let freshData = try #require(renderPNGData(freshHosted.hosting))
        freshHosted.window.contentView = nil

        // Subject: a calendar created at landscape size, then rotated to the same portrait size —
        // this is what actually happens when a device rotates while the calendar is on screen.
        let rotatedViewModel = CalendarViewModel.snapshot(selection: .single(nil))
        let rotatedView = CalendarView(
            model: rotatedViewModel,
            configuration: CalendarConfiguration(scrollMode: .horizontal)
        )
        let landscapeSize = CGSize(width: 844, height: 320)
        let rotatedHosted = hostView(rotatedView, size: landscapeSize)
        // Warm up: render once at landscape size so any width-derived @State is populated,
        // matching what happens on a real device before rotation occurs.
        _ = renderPNGData(rotatedHosted.hosting)

        rotatedHosted.hosting.frame = CGRect(origin: .zero, size: portraitSize)
        let rotatedData = try #require(renderPNGData(rotatedHosted.hosting))
        rotatedHosted.window.contentView = nil

        #expect(freshData == rotatedData)
    }

    @Test("hosted horizontal view runs lifecycle without crashing")
    func hostedHorizontalViewRunsLifecycleWithoutCrashing() {
        let viewModel = CalendarViewModel.snapshot(selection: .single(nil))
        let theme = Theme()
        let view = CalendarBodyHorizontalView(viewModel: viewModel)
            .environment(theme)
            .environment(Typography.default)
            .environment(\.locale, viewModel.locale)
            .environment(\.layoutDirection, viewModel.layoutDirection)

        let hosted = hostView(view)
        hosted.window.contentView = nil

        #expect(hosted.hosting.fittingSize.width >= 0)
    }
    #endif
}
