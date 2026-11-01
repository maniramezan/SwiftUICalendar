import SwiftUI

extension EnvironmentValues {
    /// Active fold rectangles in the viewport's physical coordinates, used for hosted testing.
    @Entry var calendarFoldRegions: [CGRect] = []
    @Entry var calendarHasCompanionMonth = false
    @Entry var calendarIsCompanionPanel = false
    @Entry var calendarPanelHeaders: CalendarPanelHeaders?
}

/// Shares the primary header's natural height so month grids align without constraining text.
@MainActor
@Observable
final class CalendarPanelHeaders {
    var primaryHeight: CGFloat = 0
}

/// Reads fold geometry synchronously in the same coordinate space used to place the month panels.
enum CalendarFoldRegions {
    static func read(in geometry: GeometryProxy) -> [CGRect] {
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(iOS 27.1, macOS 27.1, *) {
            return geometry.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
                .filter(\.isActive)
                .map(\.frame)
        }
        #endif
        return []
    }
}
