import Foundation
import SwiftUI

/// Small helpers for localization usage in SwiftUI and UIKit/AppKit.
/// Use `Text("my_key".localizedKey)` in SwiftUI, or `"my_key".localized` for String APIs.
/// The localization only needs the key — no pluralization or advanced formatting is performed here.
extension String {

  /// Returns a LocalizedStringKey for use with SwiftUI Text initializers.
  /// Example: Text("hello_key".localizedKey)
  var localizedKey: LocalizedStringKey { LocalizedStringKey(self) }

  /// Returns a LocalizedStringResource that resolves from the package string catalog
  /// and bundle (Bundle.module). Use with `String(localized:)` or `Text(String(localized:))`.
  var localizedResource: LocalizedStringResource {
    LocalizedStringResource(
      String.LocalizationValue(self),
      table: nil,
      locale: .current,
      bundle: Bundle.module,
      comment: nil
    )
  }

  /// Returns a localized String using the package string catalogue (Bundle.module).
  /// Example: label.text = "hello_key".localized
  var localized: String {
    String(localized: localizedResource)
  }

  /// Returns a formatted localized string using the current locale.
  /// Example: "greeting_format".localized(with: "John")
  func localized(with args: CVarArg...) -> String {
    let resolved = String(localized: localizedResource)
    return String(format: resolved, locale: Locale.current, arguments: args)
  }
}
