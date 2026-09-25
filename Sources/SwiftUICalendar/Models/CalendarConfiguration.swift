import Foundation
import SwiftUI

/// Immutable presentation behavior for a calendar view.
public struct CalendarConfiguration: Equatable, Sendable {
    public enum ScrollMode: Equatable, Sendable {
        case none
        case vertical
        case horizontal
    }

    public enum HorizontalHeightMode: Equatable, Sendable {
        case hugContent
        case sixRows
    }

    /// Controls whether the calendar grid fills its container or retains its natural width.
    ///
    /// Day cells are always clamped between a minimum hit-target size and a maximum size. This
    /// setting decides what happens to the leftover width in a container wider than seven
    /// maximum-size cells, which is common on macOS windows, iPad, and landscape iPhone.
    public enum GridSizing: Equatable, Sendable {
        /// Centers the grid once day cells reach their maximum size; otherwise fills the available width.
        ///
        /// This is the default: narrow containers spread the grid edge to edge, and wide containers
        /// stop stretching day spacing and center a natural-width grid instead.
        case adaptive
        /// Always keeps the grid at its natural day-cell width.
        ///
        /// The grid never stretches, so it stays visually identical across container widths and is
        /// centered in anything wider than itself.
        case compact
        /// Always distributes the grid across the available width.
        ///
        /// Columns keep filling the container no matter how wide it gets, so day spacing grows with
        /// the window while cell height stays capped.
        case flexible
    }

    /// Keyboard shortcuts the calendar handles while it holds focus.
    ///
    /// The calendar consumes these key presses only while it is the focused view, but a host app may
    /// still own some of them — `⌘T` is "new tab" in many document apps, for example. Narrow this set
    /// to hand those back:
    ///
    /// ```swift
    /// // Arrow-key browsing and month paging, but leave ⌘T to the app.
    /// CalendarConfiguration(keyboardNavigation: [.arrows, .monthShortcuts])
    ///
    /// // No keyboard handling at all.
    /// CalendarConfiguration(keyboardNavigation: [])
    /// ```
    public struct KeyboardNavigation: OptionSet, Equatable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Arrow keys move the cursor by a day or a week; Return and Space select the focused day.
        public static let arrows = KeyboardNavigation(rawValue: 1 << 0)
        /// `⌘←` and `⌘→` move to the previous and next month, following the layout direction.
        public static let monthShortcuts = KeyboardNavigation(rawValue: 1 << 1)
        /// `⌘T` returns to today when today is inside the calendar's date range.
        public static let today = KeyboardNavigation(rawValue: 1 << 2)

        /// Every shortcut the calendar knows about. This is the default.
        public static let all: KeyboardNavigation = [.arrows, .monthShortcuts, .today]
    }

    public struct YearSelection: Equatable, Sendable {
        public enum Style: Equatable, Sendable {
            case wheel
            case menu
            case custom
        }

        public var style: Style
        public var minYear: Int?
        public var maxYear: Int?

        public init(style: Style = .wheel, minYear: Int? = nil, maxYear: Int? = nil) {
            self.style = style
            self.minYear = minYear
            self.maxYear = maxYear
        }
    }

    public var scrollMode: ScrollMode
    public var horizontalHeightMode: HorizontalHeightMode
    /// How the day grid resolves its width inside the available container.
    public var gridSizing: GridSizing
    public var showsHeader: Bool
    public var yearSelection: YearSelection
    /// Keyboard shortcuts the calendar handles while focused.
    public var keyboardNavigation: KeyboardNavigation

    public init(
        scrollMode: ScrollMode = .none,
        horizontalHeightMode: HorizontalHeightMode = .sixRows,
        gridSizing: GridSizing = .adaptive,
        showsHeader: Bool = true,
        yearSelection: YearSelection = YearSelection(),
        keyboardNavigation: KeyboardNavigation = .all
    ) {
        self.scrollMode = scrollMode
        self.horizontalHeightMode = horizontalHeightMode
        self.gridSizing = gridSizing
        self.showsHeader = showsHeader
        self.yearSelection = yearSelection
        self.keyboardNavigation = keyboardNavigation
    }
}

extension EnvironmentValues {
    @Entry var calendarConfiguration = CalendarConfiguration()
}
