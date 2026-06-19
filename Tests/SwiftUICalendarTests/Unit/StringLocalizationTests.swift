import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

@Suite("String Localization Tests")
struct StringLocalizationTests {

  @Test("localized resolves a known key from the package catalog")
  func localizedResolvesKnownKey() {
    // The key exists in the package string catalog, so it should resolve to non-empty text that
    // is not the raw key itself.
    let resolved = "Calendar.Today".localized
    #expect(!resolved.isEmpty)
    #expect(resolved != "Calendar.Today")
  }

  @Test("localized returns the key for an unknown string")
  func localizedFallsBackToKey() {
    let unknown = "Calendar.NonExistentKey.\(UUID().uuidString)"
    #expect(unknown.localized == unknown)
  }

  @Test("localized(with:) interpolates an argument")
  func localizedWithArgument() {
    // "Calendar.Day.Secondary" is a format string containing a %@ placeholder.
    let resolved = "Calendar.Day.Secondary".localized(with: "12")
    #expect(resolved.contains("12"))
  }

  @Test("localizedKey wraps the string as a LocalizedStringKey")
  func localizedKeyWraps() {
    #expect("Calendar.Today".localizedKey == LocalizedStringKey("Calendar.Today"))
  }
}
