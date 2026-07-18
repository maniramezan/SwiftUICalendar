//
//  CalendarDayView.swift
//  SwiftUICalendar
//
//  Created by Mani Ramezan on 12/22/25.
//

import SwiftUI

/// Context passed to day views to render a specific date.
///
/// Custom day views receive this value from `Theme.Day.setDayContent`. Use it to display the date,
/// reflect selection state, and call `onSelect` when the user selects the cell.
///
/// ```swift
/// struct CompactDayCell: CalendarDayView {
///     let context: CalendarDayContext
///
///     init(context: CalendarDayContext) {
///         self.context = context
///     }
///
///     var body: some View {
///         Text(context.dayLabel)
///             .padding(8)
///             .background(context.isSelected ? Color.blue : Color.clear)
///             .contentShape(Rectangle())
///             .onTapGesture { context.onSelect(context.date) }
///     }
/// }
/// ```
public struct CalendarDayContext {
  /// The underlying absolute date represented by the cell.
  public let date: Date
  /// The day number within the active calendar month.
  public let day: Int
  /// Localized day label for display.
  ///
  /// This value is already formatted for the calendar locale and numbering system.
  public let dayLabel: String
  /// Indicates whether the date is today.
  public let isToday: Bool
  /// Indicates whether the date is selected.
  public let isSelected: Bool
  /// Indicates whether the date belongs to the currently displayed month.
  public let isInCurrentMonth: Bool
  /// Day-level theme configuration.
  public let theme: Theme.Day
  /// Typography configuration for day rendering.
  public let typography: Typography
  /// Callback invoked when the day is selected.
  ///
  /// Pass `date` back to this closure from your custom day view to keep the view model's
  /// selection behavior consistent with built-in day cells.
  public let onSelect: (Date) -> Void
  /// Optional secondary label, such as an alternate calendar day number.
  public let secondaryLabel: String?

  /// Creates a day context with the provided values.
  ///
  /// Most apps do not instantiate this directly; SwiftUICalendar creates contexts while
  /// rendering day cells. It is public so custom day views and tests can construct examples.
  ///
  /// - Parameters:
  ///   - date: The date represented by the cell.
  ///   - day: The day number within the month.
  ///   - dayLabel: Localized label to display.
  ///   - isToday: Whether the date is today.
  ///   - isSelected: Whether the date is selected.
  ///   - isInCurrentMonth: Whether the date belongs to the current month.
  ///   - theme: Day-level theme configuration.
  ///   - typography: Typography configuration for day rendering.
  ///   - onSelect: Callback invoked when the date is selected.
  ///   - secondaryLabel: Optional secondary label text.
  public init(
    date: Date,
    day: Int,
    dayLabel: String,
    isToday: Bool,
    isSelected: Bool,
    isInCurrentMonth: Bool,
    theme: Theme.Day,
    typography: Typography,
    onSelect: @escaping (Date) -> Void,
    secondaryLabel: String? = nil
  ) {
    self.date = date
    self.day = day
    self.dayLabel = dayLabel
    self.isToday = isToday
    self.isSelected = isSelected
    self.isInCurrentMonth = isInCurrentMonth
    self.theme = theme
    self.typography = typography
    self.onSelect = onSelect
    self.secondaryLabel = secondaryLabel
  }
}

/// A day view that can be constructed from a `CalendarDayContext`.
///
/// Conform to this protocol to provide a custom cell renderer through `Theme.Day.setDayContent`.
/// Your view should visually represent `context.isSelected`, `context.isToday`, and
/// `context.isInCurrentMonth`, then call `context.onSelect(context.date)` on activation.
///
/// ```swift
/// struct RingDayView: CalendarDayView {
///     let context: CalendarDayContext
///
///     init(context: CalendarDayContext) {
///         self.context = context
///     }
///
///     var body: some View {
///         Text(context.dayLabel)
///             .frame(width: 44, height: 44)
///             .overlay(Circle().stroke(context.isToday ? .orange : .clear))
///             .onTapGesture { context.onSelect(context.date) }
///     }
/// }
/// ```
@MainActor
public protocol CalendarDayView: View {
  /// Creates a day view from the provided context.
  init(context: CalendarDayContext)
}
