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

## TCA Integration Boundary

An optional TCA adapter is a follow-up feature, not a dependency of the 0.1.0 library.
It should own value state in the reducer and receive explicit selection/navigation actions from
a state-driven rendering surface. Both the MVVM model and that adapter should use the same
Foundation calendar and selection operations.

Avoid storing a mutable `CalendarViewModel` inside reducer state or mirroring changes between two
independent state owners. An opt-in SwiftPM trait can control adapter packaging once that
rendering boundary exists; it does not replace the need for a single authoritative state owner.
