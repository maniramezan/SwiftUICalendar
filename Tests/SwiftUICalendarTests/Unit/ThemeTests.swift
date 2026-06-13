import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Theme Tests")
struct ThemeTests {

  @Test("Theme.default returns independent instances")
  func defaultReturnsIndependentInstances() {
    let first = Theme.default
    first.scrollMode = .horizontal
    first.horizontalHeightMode = .hugContent
    first.day.emptyDayBorderColorWidth = 3

    let second = Theme.default

    #expect(second.scrollMode == .none)
    #expect(second.horizontalHeightMode == .sixRows)
    #expect(second.day.emptyDayBorderColorWidth == 0)
  }

  @Test("useSquareDualCalendarDayView applies optional secondary label mode")
  func useSquareDualCalendarDayViewAppliesSecondaryLabelMode() {
    let theme = Theme()

    theme.day.useSquareDualCalendarDayView(secondaryLabel: .hebrew)

    let date = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2025, month: 6, day: 15)
    )!
    #expect(theme.day.secondaryLabelMode.label(for: date) != nil)
  }

  @Test("SecondaryLabelMode resolves expected labels")
  func secondaryLabelModesResolveLabels() {
    let date = Calendar(identifier: .gregorian).date(
      from: DateComponents(year: 2025, month: 6, day: 15)
    )!

    #expect(Theme.Day.SecondaryLabelMode.none.label(for: date) == nil)
    #expect(Theme.Day.SecondaryLabelMode.calendar(.gregorian).label(for: date) == "15")
    #expect(Theme.Day.SecondaryLabelMode.custom { _ in "custom" }.label(for: date) == "custom")
    #expect(Theme.Day.SecondaryLabelMode.persian.label(for: date) != nil)
    #expect(Theme.Day.SecondaryLabelMode.hebrew.label(for: date) != nil)
    #expect(Theme.Day.SecondaryLabelMode.islamic.label(for: date) != nil)
    #expect(Theme.Day.SecondaryLabelMode.japanese.label(for: date) != nil)
  }

  @Test("adaptiveGlass renders fallback shape variants")
  func adaptiveGlassRendersFallbackShapeVariants() {
    let view = HStack {
      Text("Capsule")
        .adaptiveGlass(shape: .capsule)
      Text("Rounded")
        .adaptiveGlass(shape: .roundedRectangle(cornerRadius: 8))
    }
    .frame(width: 220, height: 80)

    let hosting = NSHostingView(rootView: view)
    hosting.frame = CGRect(origin: .zero, size: CGSize(width: 220, height: 80))
    let window = NSWindow(
      contentRect: hosting.frame,
      styleMask: [],
      backing: .buffered,
      defer: false
    )
    window.contentView = hosting
    window.layoutIfNeeded()
    hosting.layoutSubtreeIfNeeded()
    if let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
      hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
    } else {
      hosting.displayIfNeeded()
    }

    #expect(hosting.fittingSize.width >= 0)
  }
}
