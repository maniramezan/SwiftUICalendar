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
