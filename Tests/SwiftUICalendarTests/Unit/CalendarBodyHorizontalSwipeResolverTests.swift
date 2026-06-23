import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("CalendarBodyHorizontalView Swipe Resolver Tests")
struct CalendarBodyHorizontalSwipeResolverTests {

  // MARK: - Direction mapping

  @Test("Left swipe (negative translation) returns +1 (go to next)")
  func leftSwipeReturnsNext() {
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: -101, threshold: 100) == 1)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: -200, threshold: 100) == 1)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: -390, threshold: 130) == 1)
  }

  @Test("Right swipe (positive translation) returns -1 (go to previous)")
  func rightSwipeReturnsPrevious() {
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: 101, threshold: 100) == -1)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: 200, threshold: 100) == -1)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: 390, threshold: 130) == -1)
  }

  // MARK: - Threshold boundary

  @Test("Translation exactly at threshold does not navigate")
  func translationExactlyAtThresholdIsNil() {
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: 100, threshold: 100) == nil)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: -100, threshold: 100) == nil)
  }

  @Test("Translation below threshold does not navigate")
  func translationBelowThresholdIsNil() {
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: 50, threshold: 100) == nil)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: -50, threshold: 100) == nil)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: 0, threshold: 100) == nil)
  }

  // MARK: - Symmetry

  @Test("Positive and negative translations of equal magnitude return opposite deltas")
  func symmetry() {
    let translations: [CGFloat] = [110, 150, 250, 390]
    let threshold: CGFloat = 100
    for t in translations {
      let pos = HorizontalMonthSwipeResolver.monthDelta(for: t, threshold: threshold)
      let neg = HorizontalMonthSwipeResolver.monthDelta(for: -t, threshold: threshold)
      #expect(pos == -1)
      #expect(neg == 1)
      if let p = pos, let n = neg {
        #expect(p == -n)
      }
    }
  }

  // MARK: - Momentum and clamping

  @Test("resolvedTranslation uses momentum to trigger next month on a fast left fling")
  func resolvedTranslationUsesMomentumForLeftFling() {
    let resolved = HorizontalMonthSwipeResolver.resolvedTranslation(
      translation: -20,
      predictedEndTranslation: -210,
      limit: 390
    )

    #expect(resolved < -100)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: resolved, threshold: 100) == 1)
  }

  @Test("resolvedTranslation uses momentum to trigger previous month on a fast right fling")
  func resolvedTranslationUsesMomentumForRightFling() {
    let resolved = HorizontalMonthSwipeResolver.resolvedTranslation(
      translation: 18,
      predictedEndTranslation: 200,
      limit: 390
    )

    #expect(resolved > 100)
    #expect(HorizontalMonthSwipeResolver.monthDelta(for: resolved, threshold: 100) == -1)
  }

  @Test("clampedTranslation respects both positive and negative limits")
  func clampedTranslationRespectsLimits() {
    #expect(HorizontalMonthSwipeResolver.clampedTranslation(500, limit: 390) == 390)
    #expect(HorizontalMonthSwipeResolver.clampedTranslation(-500, limit: 390) == -390)
    #expect(HorizontalMonthSwipeResolver.clampedTranslation(120, limit: 390) == 120)
    #expect(HorizontalMonthSwipeResolver.clampedTranslation(-120, limit: 390) == -120)
  }

  @Test("clampedTranslation handles zero limit gracefully")
  func clampedTranslationZeroLimit() {
    #expect(HorizontalMonthSwipeResolver.clampedTranslation(100, limit: 0) == 0)
    #expect(HorizontalMonthSwipeResolver.clampedTranslation(-100, limit: 0) == 0)
  }

  @Test("resolvedTranslation is clamped within limit")
  func resolvedTranslationIsClamped() {
    let resolved = HorizontalMonthSwipeResolver.resolvedTranslation(
      translation: 300,
      predictedEndTranslation: 800,
      limit: 390
    )
    #expect(resolved <= 390)
    #expect(resolved >= -390)
  }
}

// MARK: - Trackpad / scroll-wheel paging resolver

@Suite("Horizontal Scroll Paging Resolver Tests")
struct HorizontalScrollPagingResolverTests {

  private let threshold: CGFloat = 30

  @Test("Leftward scroll past threshold pages to the next month and resets")
  func leftwardScrollPagesNext() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: -20, deltaX: -15, deltaY: 0,
      isMomentum: false, didBegin: false, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == 1)
    #expect(result.accumulated == 0)
  }

  @Test("Rightward scroll past threshold pages to the previous month and resets")
  func rightwardScrollPagesPrevious() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: 20, deltaX: 15, deltaY: 0,
      isMomentum: false, didBegin: false, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == -1)
    #expect(result.accumulated == 0)
  }

  @Test("Small scroll below threshold accumulates without paging")
  func belowThresholdAccumulates() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: -5, deltaX: -10, deltaY: 0,
      isMomentum: false, didBegin: false, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == nil)
    #expect(result.accumulated == -15)
  }

  @Test("Momentum events are ignored")
  func momentumIgnored() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: -25, deltaX: -100, deltaY: 0,
      isMomentum: true, didBegin: false, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == nil)
    #expect(result.accumulated == -25)
  }

  @Test("Vertical-dominant scroll is ignored")
  func verticalDominantIgnored() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: 0, deltaX: 5, deltaY: 40,
      isMomentum: false, didBegin: false, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == nil)
    #expect(result.accumulated == 0)
  }

  @Test("A new gesture (didBegin) resets the accumulator before adding")
  func didBeginResetsAccumulator() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: 999, deltaX: -10, deltaY: 0,
      isMomentum: false, didBegin: true, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == nil)
    #expect(result.accumulated == -10)
  }

  @Test("Gesture end below threshold clears the accumulator")
  func didEndResetsAccumulator() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: -10, deltaX: -5, deltaY: 0,
      isMomentum: false, didBegin: false, didEnd: true, threshold: threshold)
    #expect(result.pageDelta == nil)
    #expect(result.accumulated == 0)
  }

  @Test("Zero horizontal delta is ignored")
  func zeroDeltaIgnored() {
    let result = HorizontalScrollPagingResolver.resolve(
      accumulated: 12, deltaX: 0, deltaY: 0,
      isMomentum: false, didBegin: false, didEnd: false, threshold: threshold)
    #expect(result.pageDelta == nil)
    #expect(result.accumulated == 12)
  }
}

#if os(macOS)
  @MainActor
  @Suite("Horizontal Scroll Wheel Monitor Tests")
  struct HorizontalScrollWheelMonitorTests {

    @Test("Leftward scroll past threshold emits a next-month page")
    func leftwardEmitsNext() {
      var pages: [Int] = []
      let monitor = HorizontalScrollWheelMonitor(threshold: 30) { pages.append($0) }
      monitor.fold(deltaX: -40, deltaY: 0, isMomentum: false, didBegin: true, didEnd: false)
      #expect(pages == [1])
    }

    @Test("Rightward scroll past threshold emits a previous-month page")
    func rightwardEmitsPrevious() {
      var pages: [Int] = []
      let monitor = HorizontalScrollWheelMonitor(threshold: 30) { pages.append($0) }
      monitor.fold(deltaX: 40, deltaY: 0, isMomentum: false, didBegin: true, didEnd: false)
      #expect(pages == [-1])
    }

    @Test("Small scrolls accumulate across samples before paging")
    func accumulatesAcrossSamples() {
      var pages: [Int] = []
      let monitor = HorizontalScrollWheelMonitor(threshold: 30) { pages.append($0) }
      monitor.fold(deltaX: -10, deltaY: 0, isMomentum: false, didBegin: true, didEnd: false)
      monitor.fold(deltaX: -10, deltaY: 0, isMomentum: false, didBegin: false, didEnd: false)
      #expect(pages.isEmpty)
      monitor.fold(deltaX: -20, deltaY: 0, isMomentum: false, didBegin: false, didEnd: false)
      #expect(pages == [1])
    }

    @Test("Momentum and vertical-dominant scrolls do not page")
    func ignoresMomentumAndVertical() {
      var pages: [Int] = []
      let monitor = HorizontalScrollWheelMonitor(threshold: 30) { pages.append($0) }
      monitor.fold(deltaX: -100, deltaY: 0, isMomentum: true, didBegin: false, didEnd: false)
      monitor.fold(deltaX: 5, deltaY: 80, isMomentum: false, didBegin: false, didEnd: false)
      #expect(pages.isEmpty)
    }

    @Test("stop without start is a no-op")
    func stopWithoutStartIsNoop() {
      let monitor = HorizontalScrollWheelMonitor(threshold: 30) { _ in }
      monitor.stop()
    }
  }
#endif
