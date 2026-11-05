import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Decides where day cells may grow past the phone-sized ceiling into space the window has to spare.
///
/// A regular-width iPad grows every scroll mode: a compact width, which Split View and Stage Manager
/// report at any window size, keeps the standard ceiling. macOS has no size classes and its windows
/// are freely resizable, so it grows by window size instead — but only the fixed and horizontal
/// months, which are bound by height as well as width. The vertical list scrolls, so only its width
/// would bound the cells, and a wide window would make them taller than they are useful.
///
/// Whether a month actually grows is then decided by ``CalendarMetrics/growingCells(toFitHeight:controls:)``,
/// which never goes below the standard ceiling, so a short window keeps the standard cells either way.
enum CalendarCellGrowth {
    @MainActor
    static func isAllowed(
        sizeClass: UserInterfaceSizeClass?, scrollMode: CalendarConfiguration.ScrollMode,
        isPad: Bool? = nil
    ) -> Bool {
        #if os(macOS)
        return scrollMode != .vertical
        #else
        return (isPad ?? (UIDevice.current.userInterfaceIdiom == .pad)) && sizeClass == .regular
        #endif
    }
}

extension EnvironmentValues {
    @Entry var calendarDeviceIsPad: Bool? = nil
}
