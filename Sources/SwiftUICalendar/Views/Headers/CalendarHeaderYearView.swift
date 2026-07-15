import OSLog
import SwiftCommons
import SwiftUI

struct CalendarHeaderYearView: View {
  @Environment(CalendarViewModel.self) var model
  @Environment(Theme.self) var theme

  private let logger = Logger.swiftUICalendar(for: Self.self)

  /// The lower bound offered by the picker. Clamped to the calendar's own navigable range so a
  /// misconfigured override never offers a year the calendar can't navigate to.
  private var effectiveMinYear: Int {
    Self.effectiveMinYear(model: model, override: theme.yearSelection.minYear)
  }

  /// The upper bound offered by the picker. Clamped to the calendar's own navigable range so a
  /// misconfigured override never offers a year the calendar can't navigate to.
  private var effectiveMaxYear: Int {
    Self.effectiveMaxYear(model: model, override: theme.yearSelection.maxYear)
  }

  private var yearItems: [YearItem] {
    Self.yearItems(for: model, minYear: effectiveMinYear, maxYear: effectiveMaxYear)
  }

  private var yearItemsById: [Int: YearItem] {
    Dictionary(uniqueKeysWithValues: yearItems.map { ($0.id, $0) })
  }

  /// Resolves the effective lower bound: the configured override, clamped to the calendar's own
  /// minimum, falling back to the calendar's minimum when unset.
  static func effectiveMinYear(model: CalendarViewModel, override: Int?) -> Int {
    guard let override else { return model.minYear }
    return max(override, model.minYear)
  }

  /// Resolves the effective upper bound: the configured override, clamped to the calendar's own
  /// maximum, falling back to the calendar's maximum when unset.
  static func effectiveMaxYear(model: CalendarViewModel, override: Int?) -> Int {
    guard let override else { return model.maxYear }
    return min(override, model.maxYear)
  }

  static func yearItems(for model: CalendarViewModel, minYear: Int? = nil, maxYear: Int? = nil)
    -> [YearItem]
  {
    let lowerBound = minYear ?? model.minYear
    let upperBound = maxYear ?? model.maxYear
    // A misconfigured override (min > max) falls back to the calendar's own full range rather
    // than producing an empty picker.
    let range =
      lowerBound <= upperBound ? (lowerBound...upperBound) : (model.minYear...model.maxYear)
    return range.map {
      YearItem(id: $0, title: NumberFormatter.formatYear($0, locale: model.locale))
    }
  }

  static func selectedYearItem(
    currentYear: Int,
    itemsById: [Int: YearItem],
    items: [YearItem]
  ) -> YearItem {
    itemsById[currentYear] ?? items[0]
  }

  private var selectedItemBinding: Binding<YearItem> {
    Binding(
      get: {
        Self.selectedYearItem(
          currentYear: model.currentYear,
          itemsById: yearItemsById,
          items: yearItems
        )
      },
      set: { newItem in
        model.currentYear = newItem.id
      }
    )
  }

  var body: some View {
    CalendarHeaderChevronRow(
      onPrevious: {
        do {
          try model.updateYearToPreviousYear()
        } catch {
          logger.error("Failed to navigate to previous year", error: error)
        }
      },
      onNext: {
        do {
          try model.updateYearToNextYear()
        } catch {
          logger.error("Failed to navigate to next year", error: error)
        }
      },
      isPreviousDisabled: !model.canNavigateToPreviousYear,
      isNextDisabled: !model.canNavigateToNextYear,
      content: {
        switch theme.yearSelection.style {
        case .wheel:
          YearWheelPickerView(items: yearItems, currentValue: selectedItemBinding)
        case .menu:
          YearMenuPickerView(items: yearItems, currentValue: selectedItemBinding)
        case .custom:
          YearDecadeGridPickerView(
            minYear: effectiveMinYear,
            maxYear: effectiveMaxYear,
            currentValue: selectedItemBinding,
            formatTitle: { NumberFormatter.formatYear($0, locale: model.locale) }
          )
        }
      }
    )
  }
}

#Preview {
  CalendarHeaderYearView()
    .environment(CalendarViewModel.test(identifier: .persian))
    .environment(Theme.default)
}
