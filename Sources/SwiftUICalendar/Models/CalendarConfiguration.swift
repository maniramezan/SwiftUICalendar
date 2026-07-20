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
  public enum GridSizing: Equatable, Sendable {
    /// Centers the grid once day cells reach their maximum size; otherwise fills the available width.
    case adaptive
    /// Always keeps the grid at its natural day-cell width.
    case compact
    /// Always distributes the grid across the available width.
    case flexible
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
  public var gridSizing: GridSizing
  public var showsHeader: Bool
  public var yearSelection: YearSelection

  public init(
    scrollMode: ScrollMode = .none,
    horizontalHeightMode: HorizontalHeightMode = .sixRows,
    gridSizing: GridSizing = .adaptive,
    showsHeader: Bool = true,
    yearSelection: YearSelection = YearSelection()
  ) {
    self.scrollMode = scrollMode
    self.horizontalHeightMode = horizontalHeightMode
    self.gridSizing = gridSizing
    self.showsHeader = showsHeader
    self.yearSelection = yearSelection
  }
}

extension EnvironmentValues {
  @Entry var calendarConfiguration = CalendarConfiguration()
}
