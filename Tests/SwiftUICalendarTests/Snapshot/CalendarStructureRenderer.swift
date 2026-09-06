import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import SwiftUICalendar

// MARK: - Structural (text) snapshots
//
// These snapshots serialize the *state that drives rendering* — the resolved month grid, selection
// roles, localization, layout direction, and the pure grid-layout math — into a deterministic text
// document. They render identically on every machine and OS (no simulator, no pixel diffing, no
// `SNAPSHOT_ASSERTIONS` gate, no EXIF noise), and their diffs are readable in a pull request.
//
// Genuine view-layer behavior (LazyVStack anchor recovery, hit targets, glass fallbacks) stays in
// the hosted unit tests under `Tests/SwiftUICalendarTests/Unit/`.

// MARK: Assertion helpers

/// Serializes the calendar's rendering-relevant state for `model` and asserts it against the stored
/// text baseline. `width` feeds the pure `CalendarGridLayout` math; `monthSpan` adds that many
/// months on each side of the visible month (scroll modes pass `1`).
@MainActor
func assertCalendarStructure(
  model: CalendarViewModel,
  configuration: CalendarConfiguration = CalendarConfiguration(),
  theme: Theme = Theme(),
  width: CGFloat = 390,
  monthSpan: Int = 0,
  named name: String? = nil,
  file: StaticString = #filePath,
  testName: String = #function,
  line: UInt = #line
) {
  let document = CalendarStructure.render(
    model: model,
    configuration: configuration,
    theme: theme,
    width: width,
    monthSpan: monthSpan
  )
  withSnapshotTesting(record: globalRecordMode) {
    assertSnapshot(
      of: document, as: .lines, named: name, file: file, testName: testName, line: line)
  }
}

/// Serializes a single `CalendarDayContext` and the day renderer the theme resolves for it. Used by
/// the day-cell snapshots, which build a context directly instead of going through a view model.
@MainActor
func assertDayContextStructure(
  _ context: CalendarDayContext,
  rendererFor theme: Theme = Theme(),
  named name: String? = nil,
  file: StaticString = #filePath,
  testName: String = #function,
  line: UInt = #line
) {
  let document = CalendarStructure.render(dayContext: context, theme: theme)
  withSnapshotTesting(record: globalRecordMode) {
    assertSnapshot(
      of: document, as: .lines, named: name, file: file, testName: testName, line: line)
  }
}

// MARK: Renderer

enum CalendarStructure {

  @MainActor
  static func render(
    model: CalendarViewModel,
    configuration: CalendarConfiguration,
    theme: Theme,
    width: CGFloat,
    monthSpan: Int
  ) -> String {
    let calendar = model.state.calendar
    var lines: [String] = []

    lines.append("calendar: \(model.calendarIdentifier)")
    lines.append("locale: \(model.locale.identifier)")
    lines.append("layoutDirection: \(direction(model.layoutDirection))")
    lines.append("scrollMode: \(configuration.scrollMode)")
    lines.append("gridSizing: \(configuration.gridSizing)")
    lines.append("horizontalHeightMode: \(configuration.horizontalHeightMode)")
    lines.append("showsHeader: \(configuration.showsHeader)")
    lines.append("dayRenderer: \(rendererName(theme.day.renderer))")
    lines.append("secondaryLabel: \(secondaryName(theme.day.secondaryLabelMode))")
    lines.append("selection: \(describe(model.selection, calendar: calendar))")

    let metrics = CalendarMetrics.default
    let layout = CalendarGridLayout(
      containerWidth: width, metrics: metrics, sizing: configuration.gridSizing)
    let isCompact = layout.gridWidth != layout.width
    lines.append(
      "layout(width=\(number(width))): cell=\(number(layout.cellSize)) "
        + "gridWidth=\(number(layout.gridWidth)) compactWidth=\(isCompact)")
    lines.append("weekdayHeader: \(model.headerTitles.joined(separator: " "))")
    lines.append("")

    let center = model.visibleMonth
    let identifiers = (-monthSpan...monthSpan).compactMap {
      $0 == 0 ? center : model.monthIdentifier(offset: $0, from: center)
    }
    for identifier in identifiers {
      lines.append(
        contentsOf: renderMonth(identifier, model: model, theme: theme, calendar: calendar))
      lines.append("")
    }

    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
  }

  @MainActor
  private static func renderMonth(
    _ identifier: MonthIdentifier,
    model: CalendarViewModel,
    theme: Theme,
    calendar: Calendar
  ) -> [String] {
    guard let snapshot = model.monthSnapshot(for: identifier) else {
      return ["month: <unresolved m\(identifier.month) y\(identifier.year)>"]
    }

    let leap = identifier.isLeapMonth ? " leap" : ""
    var lines = [
      "month: \(snapshot.title) "
        + "[\(identifier.calendarIdentifier) y\(identifier.year) m\(identifier.month) "
        + "era\(identifier.era)\(leap)] rows=\(snapshot.rowCount)"
    ]

    let bounds = rangeBounds(model.selection, calendar: calendar)
    let secondary = theme.day.secondaryLabelMode
    for start in stride(from: 0, to: snapshot.days.count, by: 7) {
      let week = snapshot.days[start..<min(start + 7, snapshot.days.count)]
      let cells = week.map {
        cell($0, secondary: secondary, rangeBounds: bounds, calendar: calendar)
      }
      lines.append(rstrip("  " + cells.joined(separator: " ")))
    }
    return lines
  }

  private static func cell(
    _ day: MonthSnapshot.Day,
    secondary: Theme.Day.SecondaryLabelMode,
    rangeBounds: (start: Date, end: Date)?,
    calendar: Calendar
  ) -> String {
    var token = day.dayLabel
    if let date = day.date, let label = secondary.label(for: date) {
      token += "/" + label
    }

    var flags = ""
    if !day.isInDisplayedMonth { flags += "·" }
    if day.isToday { flags += "T" }
    // `*` always reflects `MonthSnapshot.Day.isSelected` — the resolved flag the day views render —
    // for every selection mode. Range roles (`[` start, `]` end, `=` interior) are layered on top so
    // a range still fails the snapshot if the model marks its days unselected.
    if day.isSelected { flags += "*" }
    if let date = day.date, let bounds = rangeBounds {
      let start = calendar.startOfDay(for: date)
      if start == bounds.start { flags += "[" }
      if start == bounds.end { flags += "]" }
      if start > bounds.start && start < bounds.end { flags += "=" }
    }
    if !flags.isEmpty { token += "(\(flags))" }

    return token.count >= 12
      ? token
      : token + String(repeating: " ", count: 12 - token.count)
  }

  // MARK: Day context

  @MainActor
  static func render(dayContext context: CalendarDayContext, theme: Theme) -> String {
    var lines: [String] = []
    lines.append("dayRenderer: \(rendererName(theme.day.renderer))")
    lines.append("dayLabel: \(context.dayLabel)")
    lines.append("secondaryLabel: \(context.secondaryLabel ?? "none")")
    lines.append("isToday: \(context.isToday)")
    lines.append("isSelected: \(context.isSelected)")
    lines.append("isInCurrentMonth: \(context.isInCurrentMonth)")
    // `accessibilityLabel` is intentionally omitted: it resolves localized strings, which differ
    // between a local toolchain and CI. `CalendarDayAccessibilityTests` covers it directly.
    lines.append("emptyDayBorderColor: \(describe(context.theme.emptyDayBorderColor))")
    lines.append("emptyDayBorderColorWidth: \(number(context.theme.emptyDayBorderColorWidth))")
    lines.append("todayBorderColor: \(describe(context.theme.todayBorderColor))")
    lines.append("selectedBackgroundColor: \(describe(context.theme.selectedBackgroundColor))")
    return lines.joined(separator: "\n") + "\n"
  }

  // MARK: Formatting

  private static func direction(_ direction: LayoutDirection) -> String {
    direction == .rightToLeft ? "rightToLeft" : "leftToRight"
  }

  private static func rendererName(_ renderer: Theme.Day.Renderer) -> String {
    switch renderer {
    case .circle: return "circle"
    case .square: return "square"
    case .custom: return "custom"
    }
  }

  private static func secondaryName(_ mode: Theme.Day.SecondaryLabelMode) -> String {
    switch mode {
    case .none: return "none"
    case .persian: return "persian"
    case .hebrew: return "hebrew"
    case .islamic: return "islamic"
    case .japanese: return "japanese"
    case .calendar(let identifier): return "calendar(\(identifier))"
    case .custom: return "custom"
    }
  }

  private static func describe(_ selection: CalendarSelection, calendar: Calendar) -> String {
    switch selection.normalized(in: calendar) {
    case .single(nil):
      return "single(none)"
    case .single(let date?):
      return "single(\(day(date, calendar: calendar)))"
    case .range(let start, let end):
      return "range(\(start.map { day($0, calendar: calendar) } ?? "none") … "
        + "\(end.map { day($0, calendar: calendar) } ?? "none"))"
    case .multiple(let dates):
      let formatted = dates.sorted().map { day($0, calendar: calendar) }
      return "multiple([\(formatted.joined(separator: ", "))])"
    }
  }

  private static func rangeBounds(
    _ selection: CalendarSelection, calendar: Calendar
  ) -> (start: Date, end: Date)? {
    guard case .range(let start, let end) = selection.normalized(in: calendar), let start else {
      return nil
    }
    return (start, end ?? start)
  }

  /// Calendar-local `year-month-day`. Both the day string and the `startOfDay` comparisons in
  /// `cell(_:)` use the model's own calendar and time zone, so the result is machine-independent.
  private static func day(_ date: Date, calendar: Calendar) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    let year = parts.year ?? 0
    let month = parts.month ?? 0
    let dayOfMonth = parts.day ?? 0
    return String(format: "%04d-%02d-%02d", year, month, dayOfMonth)
  }

  private static func rstrip(_ line: String) -> String {
    var line = line
    while line.last == " " { line.removeLast() }
    return line
  }

  private static func number(_ value: CGFloat) -> String {
    value == value.rounded() ? String(Int(value)) : String(format: "%.2f", value)
  }

  private static func describe(_ color: Color) -> String {
    color == .clear ? "clear" : "\(color)"
  }
}
