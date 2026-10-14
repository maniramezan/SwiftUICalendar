import SwiftUI

/// Wide iOS hosts can show the calendar above another pane. Snapping an entire month in their
/// shorter viewport turns small drags into large jumps. Keep those gestures continuous while
/// preserving the existing month alignment in compact hosts and on other platforms.
struct CalendarVerticalScrollTargetBehavior: ScrollTargetBehavior {
    var alignsMonths = true

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        // Explicit navigation already supplies an exact month or day. Snapping that request
        // again can choose the previous month when the requested row exceeds the viewport.
        guard alignsMonths else { return }
        #if os(iOS)
        guard context.horizontalSizeClass != .regular else { return }
        #endif
        ViewAlignedScrollTargetBehavior(limitBehavior: .never)
            .updateTarget(&target, context: context)
    }

    @available(iOS 18.4, macOS 15.4, tvOS 18.4, watchOS 11.4, visionOS 2.4, *)
    func properties(context: PropertiesContext) -> Properties {
        // Preserve unlimited flings instead of the compact-width one-viewport limit.
        ViewAlignedScrollTargetBehavior(limitBehavior: .never).properties(context: context)
    }
}
