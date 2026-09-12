import SwiftCommons

/// Signpost recorders for the calendar's rendering hot paths.
///
/// The vertical scroll path recomputes month grids, month titles, and month offsets while the user
/// drags. When that work overruns a frame the scroll visibly stalls, and a plain `Logger` message
/// cannot tell you *how long* a step took. Signposts can — they place each interval against the
/// frame timeline.
///
/// These mirror the `Logger` factories in `Logger+SwiftUICalendar.swift` and share their subsystem,
/// so one Instruments filter covers both log messages and intervals:
///
/// ```bash
/// xcrun xctrace record --template 'os_signpost' --attach <pid>
/// ```
///
/// Recording is free when no tool is attached; `SignpostRecorder` short-circuits on `isEnabled`.
enum CalendarSignpost {

  /// The subsystem shared with ``Logger/swiftUICalendar(for:)``.
  static let subsystem = "SwiftUICalendar"

  /// Intervals for scroll-driven work: window resets, settle passes, external navigation.
  static let scroll = SignpostRecorder(subsystem: subsystem, category: "Scroll")

  /// Intervals for month grid, title, and offset resolution.
  static let rendering = SignpostRecorder(subsystem: subsystem, category: "Rendering")
}
