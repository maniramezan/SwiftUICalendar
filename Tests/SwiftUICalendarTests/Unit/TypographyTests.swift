import SwiftUI
import Testing

@testable import SwiftUICalendar

@MainActor
@Suite("Typography Tests")
struct TypographyTests {

  @Test("dayViewTypography returns fallback for unknown type")
  func dayViewTypographyReturnsFallback() {
    let typography = Typography(
      headerFont: .title,
      weekdayHeaderFont: .caption,
      dayFont: .body,
      allowsScaling: false,
      minScaleFactor: nil
    )

    let fallback = typography.dayViewTypography(for: "unknown")

    #expect(fallback.primaryFont == .body)
    #expect(fallback.secondaryFont == .caption)
  }

  @Test("setDayViewTypography registers custom typography")
  func setDayViewTypographyRegistersCustomTypography() {
    let typography = Typography.default
    let custom = DayViewTypography(primaryFont: .headline, secondaryFont: .caption2)

    typography.setDayViewTypography(custom, for: "event")

    let resolved = typography.dayViewTypography(for: "event")
    #expect(resolved.primaryFont == .headline)
    #expect(resolved.secondaryFont == .caption2)
  }

  @Test("default typography contains built-in day view entries")
  func defaultTypographyContainsBuiltInDayViewEntries() {
    let typography = Typography.default

    let circle = typography.dayViewTypography(for: DayViewType.circle)
    let squareDual = typography.dayViewTypography(for: DayViewType.squareDual)

    #expect(circle.primaryFont == typography.dayFont)
    #expect(
      squareDual.primaryFont != typography.dayFont
        || squareDual.secondaryFont != typography.dayFont
    )
  }
}
