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
  public var showsHeader: Bool
  public var yearSelection: YearSelection

  public init(
    scrollMode: ScrollMode = .none,
    horizontalHeightMode: HorizontalHeightMode = .sixRows,
    showsHeader: Bool = true,
    yearSelection: YearSelection = YearSelection()
  ) {
    self.scrollMode = scrollMode
    self.horizontalHeightMode = horizontalHeightMode
    self.showsHeader = showsHeader
    self.yearSelection = yearSelection
  }
}

extension EnvironmentValues {
  @Entry var calendarConfiguration = CalendarConfiguration()
}
