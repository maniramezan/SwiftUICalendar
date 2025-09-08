//
//  CalendarDayView.swift
//  SwiftUICalendar
//
//  Created by Mani Ramezan on 12/22/25.
//

import SwiftUI

/// Context passed to day views to render a specific date.
public struct CalendarDayContext {
    /// The underlying date represented by the cell.
    public let date: Date
    /// The day number within the month.
    public let day: Int
    /// Localized day label for display.
    public let dayLabel: String
    /// Indicates whether the date is today.
    public let isToday: Bool
    /// Indicates whether the date is selected.
    public let isSelected: Bool
    /// Indicates whether the date belongs to the current month.
    public let isInCurrentMonth: Bool
    /// Day-level theme configuration.
    public let theme: Theme.Day
    /// Typography configuration for day rendering.
    public let typography: Typography
    /// Callback invoked when the day is selected.
    public let onSelect: (Date) -> Void
    /// Optional secondary label (e.g., alternate calendar day).
    public let secondaryLabel: String?

    /// Creates a day context with the provided values.
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
@MainActor
public protocol CalendarDayView: View {
    /// Creates a day view from the provided context.
    init(context: CalendarDayContext)
}
