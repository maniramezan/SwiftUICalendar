import Testing
import SwiftUI

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyHorizontalView Layout Tests")
struct CalendarBodyHorizontalViewLayoutTests {

  @Test("layoutWidth respects the minimum calendar width")
  func layoutWidthRespectsMinimumCalendarWidth() {
    #expect(CalendarBodyHorizontalView.layoutWidth(containerWidth: 320, minCalendarWidth: 356) == 356)
    #expect(CalendarBodyHorizontalView.layoutWidth(containerWidth: 390, minCalendarWidth: 356) == 390)
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

  @Test("navigationTransition resets state when navigation is invalid")
  func navigationTransitionResetsStateWhenInvalid() {
    let fallback = CalendarViewModel.test()
    let result = CalendarBodyHorizontalView.navigationTransition(
      monthDelta: 0,
      canUpdateMonth: false,
      fallbackViewModel: fallback,
      savedCurrent: fallback,
      previousViewModel: fallback,
      currentViewModel: fallback,
      nextViewModel: fallback,
      replacementPrevious: nil,
      replacementNext: nil
    )

    #expect(result.previousViewModel === fallback)
    #expect(result.currentViewModel === fallback)
    #expect(result.nextViewModel === fallback)
    #expect(result.offset == 0)
    #expect(result.dragOffset == 0)
    #expect(!result.isNavigating)
  }

  @Test("navigationTransition resets state when month update fails at a boundary")
  func navigationTransitionResetsStateWhenMonthUpdateFails() {
    let fallback = CalendarViewModel.test()
    let saved = CalendarViewModel.test()
    let next = CalendarViewModel.test()

    let result = CalendarBodyHorizontalView.navigationTransition(
      monthDelta: 1,
      canUpdateMonth: false,
      fallbackViewModel: fallback,
      savedCurrent: saved,
      previousViewModel: fallback,
      currentViewModel: fallback,
      nextViewModel: next,
      replacementPrevious: nil,
      replacementNext: nil
    )

    #expect(result.previousViewModel === fallback)
    #expect(result.currentViewModel === fallback)
    #expect(result.nextViewModel === fallback)
    #expect(result.offset == 0)
    #expect(result.dragOffset == 0)
    #expect(!result.isNavigating)
  }

  @Test("navigationTransition rotates models forward")
  func navigationTransitionRotatesModelsForward() {
    let fallback = CalendarViewModel.test()
    let saved = CalendarViewModel.test()
    let previous = CalendarViewModel.test()
    let current = CalendarViewModel.test()
    let next = CalendarViewModel.test()
    let replacementNext = CalendarViewModel.test()

    let result = CalendarBodyHorizontalView.navigationTransition(
      monthDelta: 1,
      canUpdateMonth: true,
      fallbackViewModel: fallback,
      savedCurrent: saved,
      previousViewModel: previous,
      currentViewModel: current,
      nextViewModel: next,
      replacementPrevious: nil,
      replacementNext: replacementNext
    )

    #expect(result.previousViewModel === saved)
    #expect(result.currentViewModel === next)
    #expect(result.nextViewModel === replacementNext)
  }

  @Test("navigationTransition rotates models backward")
  func navigationTransitionRotatesModelsBackward() {
    let fallback = CalendarViewModel.test()
    let saved = CalendarViewModel.test()
    let previous = CalendarViewModel.test()
    let current = CalendarViewModel.test()
    let next = CalendarViewModel.test()
    let replacementPrevious = CalendarViewModel.test()

    let result = CalendarBodyHorizontalView.navigationTransition(
      monthDelta: -1,
      canUpdateMonth: true,
      fallbackViewModel: fallback,
      savedCurrent: saved,
      previousViewModel: previous,
      currentViewModel: current,
      nextViewModel: next,
      replacementPrevious: replacementPrevious,
      replacementNext: nil
    )

    #expect(result.previousViewModel === replacementPrevious)
    #expect(result.currentViewModel === previous)
    #expect(result.nextViewModel === saved)
  }

  @Test("synchronizedViewModels returns nil while navigating")
  func synchronizedViewModelsReturnsNilWhileNavigating() {
    let viewModel = CalendarViewModel.test()

    let result = CalendarBodyHorizontalView.synchronizedViewModels(
      viewModel: viewModel,
      isNavigating: true
    )

    #expect(result == nil)
  }

  @Test("synchronizedViewModels returns current previous and next copies")
  func synchronizedViewModelsReturnsCurrentPreviousAndNextCopies() {
    let viewModel = CalendarViewModel.test()

    let result = CalendarBodyHorizontalView.synchronizedViewModels(
      viewModel: viewModel,
      isNavigating: false
    )

    #expect(result?.current === viewModel)
    #expect(result?.previous.currentMonth == viewModel.monthMetadata(offset: -1)?.month)
    #expect(result?.next.currentMonth == viewModel.monthMetadata(offset: 1)?.month)
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
}
