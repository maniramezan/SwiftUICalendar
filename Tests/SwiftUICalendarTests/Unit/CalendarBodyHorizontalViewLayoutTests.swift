import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyHorizontalView Layout Tests")
struct CalendarBodyHorizontalViewLayoutTests {

  @Test("layoutWidth respects the minimum calendar width")
  func layoutWidthRespectsMinimumCalendarWidth() {
    #expect(
      CalendarBodyHorizontalView.layoutWidth(containerWidth: 320, minCalendarWidth: 356) == 356)
    #expect(
      CalendarBodyHorizontalView.layoutWidth(containerWidth: 390, minCalendarWidth: 356) == 390)
  }

  @Test("carousel peek reaches past the centered cell's margin into real content")
  func carouselReservesAvailableWidthForPeeks() {
    #expect(
      CalendarBodyHorizontalView.peekWidth(
        containerWidth: 390, minCalendarWidth: 356, itemSpacing: 8, minCellSize: 44, maxCellSize: 64
      ) == 17)
    #expect(
      CalendarBodyHorizontalView.pageWidth(
        containerWidth: 390, minCalendarWidth: 356, itemSpacing: 8, minCellSize: 44, maxCellSize: 64
      ) == 356)
    #expect(
      CalendarBodyHorizontalView.peekWidth(
        containerWidth: 356, minCalendarWidth: 356, itemSpacing: 8, minCellSize: 44, maxCellSize: 64
      ) == 0)
    #expect(
      CalendarBodyHorizontalView.pageWidth(
        containerWidth: 356, minCalendarWidth: 356, itemSpacing: 8, minCellSize: 44, maxCellSize: 64
      ) == 356)
  }

  @Test("carousel track exposes the parked months on mirrored RTL edges")
  func carouselTrackMirrorsPeekedMonthsInRTL() {
    let peekWidth = CalendarBodyHorizontalView.peekWidth(
      containerWidth: 390,
      minCalendarWidth: 356,
      itemSpacing: 8,
      minCellSize: 44,
      maxCellSize: 64
    )
    let pageWidth = CalendarBodyHorizontalView.pageWidth(
      containerWidth: 390,
      minCalendarWidth: 356,
      itemSpacing: 8,
      minCellSize: 44,
      maxCellSize: 64
    )

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
      CalendarBodyHorizontalView.cellSize(
        layoutWidth: 320,
        itemSpacing: 8,
        minCellSize: 44,
        maxCellSize: 64
      ) == 44
    )
    #expect(
      CalendarBodyHorizontalView.cellSize(
        layoutWidth: 600,
        itemSpacing: 8,
        minCellSize: 44,
        maxCellSize: 64
      ) == 64
    )
  }

  @Test("cellSize interpolates between bounds for mid-range widths")
  func cellSizeInterpolatesBetweenBounds() {
    // widthForCells = 400 - (8 * 6) = 352; columnWidth = 352 / 7 ≈ 50.29 → between 44 and 64.
    let size = CalendarBodyHorizontalView.cellSize(
      layoutWidth: 400,
      itemSpacing: 8,
      minCellSize: 44,
      maxCellSize: 64
    )

    #expect(size > 44)
    #expect(size < 64)
    #expect(abs(size - 352.0 / 7.0) < 0.0001)
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
    #expect(CalendarBodyHorizontalView.weekdayHeaderHeight(cellSize: 44) == 24)
    #expect(CalendarBodyHorizontalView.weekdayHeaderHeight(cellSize: 64) == 28.8)
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
    let height = CalendarBodyHorizontalView.resolvedHeight(
      rowCount: 6,
      layoutWidth: 390,
      itemSpacing: 8,
      rowSpacing: 8,
      minCellSize: 44,
      maxCellSize: 64
    )

    #expect(height == 336)
  }

  @Test("swipeThreshold respects the minimum threshold floor")
  func swipeThresholdRespectsMinimumFloor() {
    #expect(CalendarBodyHorizontalView.swipeThreshold(layoutWidth: 120) == 56)
    #expect(CalendarBodyHorizontalView.swipeThreshold(layoutWidth: 400) == 100)
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
        layoutWidth: 390
      ) == 1
    )
    #expect(
      CalendarBodyHorizontalView.resolvedMonthDelta(
        translationWidth: 40,
        predictedEndTranslationWidth: 220,
        layoutDirectionMultiplier: 1,
        layoutWidth: 390
      ) == -1
    )
    #expect(
      CalendarBodyHorizontalView.resolvedMonthDelta(
        translationWidth: 10,
        predictedEndTranslationWidth: 20,
        layoutDirectionMultiplier: 1,
        layoutWidth: 390
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
        layoutWidth: 390
      ) == -1
    )
    #expect(
      CalendarBodyHorizontalView.resolvedMonthDelta(
        translationWidth: 40,
        predictedEndTranslationWidth: 220,
        layoutDirectionMultiplier: -1,
        layoutWidth: 390
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

  @Test("container width updates defer only while a page animation is active")
  func containerWidthUpdatesDeferDuringNavigation() {
    #expect(!CalendarBodyHorizontalView.shouldDeferContainerWidthUpdate(isNavigating: false))
    #expect(CalendarBodyHorizontalView.shouldDeferContainerWidthUpdate(isNavigating: true))
  }

  #if os(macOS)
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
