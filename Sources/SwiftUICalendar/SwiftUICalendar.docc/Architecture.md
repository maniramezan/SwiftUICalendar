# Architecture and State Ownership

Use MVVM with one owner for navigation and selection state.

## MVVM

`CalendarViewModel` is a main-actor observable object. Own it in your screen's `@State` and pass it
to `CalendarView(model:)`. The model delegates calendar arithmetic to an internal Foundation
engine. `CalendarSelection` is a Sendable value type; `CalendarViewModel.Selection` remains an
alias for source compatibility. Selection transitions are independent of view rendering.

`CalendarConfiguration` contains presentation options. `Theme` and `Typography` contain visual
configuration. Drag offsets, measured sizes, and scroll positions belong to the view layer.

## Month Identity and Navigation

A `MonthIdentifier` includes the calendar identifier, era, year, month, and leap-month flag.
Capture `model.visibleMonth` and use `try model.navigate(toMonth: month)` to preserve all of
those components. The two-integer initializer defaults to a Gregorian month in the common era.

The numeric `navigate(toMonth:year:)` overload addresses a regular month in the visible era.
The year picker and `navigate(toYear:)` address that same era. Relative month/year navigation
can cross era boundaries. A month spanning an era transition is identified by the components
at its absolute start; its individual cells retain their actual dates.

Navigation supports Gregorian January 1, 1900 through December 31, 2100 in the model's time
zone. A partially supported month remains reachable; month/year navigation clamps to supported
dates. Invalid month components fail instead of silently rolling into another month.

## Shared State and Controlled Rendering

`CalendarState` is an Equatable, Sendable value containing the active Foundation calendar,
visible date, and selection. `apply(_:now:)` performs atomic transitions; rejected navigation
leaves the entire value unchanged. `CalendarAction` describes navigation, selection, calendar
switching, and Today intents. The explicit clock argument makes Today deterministic in tests.

The observable MVVM model owns this value and forwards its existing API to those transitions.
`CalendarView(state:onAction:)` accepts externally owned state. Its internal presentation model
is a read-only snapshot: all interactions go to `onAction`, and only the owner changes state.
There is no two-way synchronization or mutable model stored in reducer state.

## Optional TCA Integration

Enable the `TCA` package trait and link the `SwiftUICalendarTCA` product. The default product
continues to work without compiling or linking ComposableArchitecture. SwiftPM may still
resolve optional dependency metadata.

```swift
.package(
    url: "https://github.com/maniramezan/SwiftUICalendar",
    from: "0.1.0",
    traits: ["TCA"]
)
```

```swift
import ComposableArchitecture
import SwiftUICalendar
import SwiftUICalendarTCA

let calendar = try CalendarState(calendarIdentifier: .persian)
let store = Store(initialState: CalendarFeature.State(calendar: calendar)) {
    CalendarFeature()
}
let view = TCACalendarView(store: store)
```

Scope `CalendarFeature` from a parent reducer using ordinary TCA `Scope` composition.
Send `.view(CalendarAction)` for programmatic changes. Handle
`.delegate(.selectionChanged(selection))` to react to selection and
`.delegate(.navigationRejected(action))` to report rejected navigation. Delegate actions do not
mutate calendar state. Override `date.now` in reducer tests to control Today.

The manifest selects TCA 1.25.5 on Swift 6.2/6.3 and TCA 1.26.2 on Swift 6.4 or newer.
Each branch constrains the related Point-Free dependencies to a consistent issue-reporting
package identity. The older branch uses the versions in TCA's own release lockfile; the newer
branch requires the renamed dependency family. This prevents duplicate module names and
incompatible dependency traits during resolution. These constraints can limit versions in a
consuming app; update and validate the family together.

Run `swift test` for default MVVM coverage and `swift test --traits TCA` for the optional
reducer, controlled-view snapshots, and integration tests.
