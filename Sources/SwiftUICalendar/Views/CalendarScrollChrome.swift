import SwiftUI

/// Scroll chrome shared by the calendar's scroll views.
enum CalendarScrollChrome {
    /// A legacy macOS scroller consumes width after the viewport resolves its grid, so macOS hides
    /// it and keeps the content width independent of the user's scrollbar preference. Other
    /// platforms draw overlay indicators that take no layout space, so they stay.
    ///
    /// This is the `showsIndicators:` initializer argument rather than `.scrollIndicators(_:)`: only
    /// the argument removes the `NSScroller` itself, so a legacy scroller stays out of the layout.
    static var showsIndicators: Bool {
        #if os(macOS)
        false
        #else
        true
        #endif
    }
}
