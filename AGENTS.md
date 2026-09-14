# Repository Guidelines

## Quick Reference

```bash
swift package resolve         # after Package.swift or sibling repo changes
swift build -c debug          # fast compile check
swift test                    # all tests (unit + snapshot)
swift test --filter Unit      # unit tests only
swift test --filter Snapshot  # snapshot tests only
```

## Local Dependencies

`SwiftCommons` and `SwiftUIComponents` resolve from versioned remote releases declared in `Package.swift`. No sibling repositories are required.

Run `swift package resolve` whenever either dependency changes.

## Project Layout

```
Sources/SwiftUICalendar/
  Views/         # SwiftUI views (Body/, Headers/, Day/)
  Models/        # CalendarViewModel, Theme, Typography, SizingClass
  Extensions/    # Calendar helpers, localization, logger
  Resources/     # Localizable.xcstrings (processed at build time)
Tests/SwiftUICalendarTests/
  Unit/          # Swift Testing (@Test/@Suite) — logic tests
  Snapshot/      # Structural (text) snapshots — CalendarStructureRenderer + swift-snapshot-testing .lines
Examples/SwiftUICalendarSample/   # Sample Xcode project
```

## Coding Conventions

- Swift 6 language mode (`swiftLanguageModes: [.v6]`), minimum iOS 18 / macOS 15.
- Comments go on their own line above the code — never inline at end of line.
- Use `// MARK:` pragmas to section files.
- Use `Logger.swiftUICalendar(for: YourType.self)` for logging (wraps `SwiftCommons` logger with subsystem `"SwiftUICalendar"`). Pre-built loggers: `.calendarUI`, `.calendarLogic`, `.calendarInteraction`, `.calendarConfiguration`.

## Logging and Signposts

Both sit on `SwiftCommons` and share the `SwiftUICalendar` subsystem, so one Instruments or
`log stream` filter covers messages and intervals together.

- **Messages** — `Logger.swiftUICalendar(for: Self.self)`. Log window resets, external navigation,
  and calendar switches at `.info`; per-scroll bookkeeping at `.debug`. Never swallow an error with
  `try?` in a view: catch it and call `logger.error(_:error:context:)` with the month or action that
  failed. Log month/year numbers and identifiers, never selected dates.
- **Intervals** — `CalendarSignpost.rendering` and `CalendarSignpost.scroll`, both
  `SwiftCommons.SignpostRecorder`. Use `measure("name") { … }` for scoped work and
  `begin`/`end` when a gesture's start and finish arrive in separate callbacks. Names must be
  string literals. Recording costs nothing when no profiler is attached, so no `#if` guards.

Profile a stall with the **os_signpost** instrument, or:

```bash
xcrun xctrace record --template 'os_signpost' --attach <pid>
log stream --predicate 'subsystem == "SwiftUICalendar"' --level debug
```

## Rendering Performance

Resolving one month grid costs roughly six `Calendar` calls per day plus a `NumberFormatter`
lookup. A vertical scroll keeps six to eight months realized and every model mutation re-evaluates
all of their bodies, so uncached grids put ~2,500 calendar operations inside a single frame.

- `CalendarRenderCache` (`Models/CalendarRenderCache.swift`) memoizes month grid geometry and
  month offset resolution, keyed by a **calendar/locale/time-zone signature** — not by model
  instance, so multiple calendar instances share the memoized work. `DateFormatter` construction
  delegates to SwiftCommons' `DateFormatter.formatter(dateFormat:calendar:)` /
  `formatter(template:calendar:)` (`FormatterCache`-backed) instead of a locally owned dictionary.
- `CalendarView`'s externally owned (TCA) integration (`init(state:onAction:)`) keeps a single
  `CalendarViewModel` alive across store mutations via `@State`, syncing it in place through
  `CalendarViewModel.sync(state:onAction:)` on every re-render instead of constructing a fresh
  instance — replacing the instance wholesale would defeat `@Observable`'s per-property diffing
  and force a full re-render of every view reading `@Environment(CalendarViewModel.self)` on
  every store mutation, not just the ones whose data changed.
- Cached entries hold geometry only. `isToday` and `isSelected` are applied on read in
  `CalendarViewModel.monthSnapshot(for:)`, so a selection tap never invalidates a grid.
- Inject a private `CalendarRenderCache()` via `viewModel.renderCache` in tests; the shared
  instance persists across tests and would make entry-count assertions order-dependent.
- Month titles are also memoized in `CalendarRenderCache` (`monthTitle(for:calendar:)`), not on
  `CalendarViewModel` — moved there so a title warmed by background prefetch is visible to every
  model instance reading the same calendar signature, not just the one that prefetched it.
- **Background prefetch**: reuse caching cannot remove the cost of realizing a month the vertical
  scroll has never shown before — resolving its offset, building its grid, and formatting its
  title. `CalendarBodyVerticalView`'s `MonthPrefetchCoordinator` races ahead of the scroll
  direction (inferred from consecutive `scrollPosition` values) via
  `CalendarRenderCache.prefetchMonth(offset:from:calendar:engine:)`, computing up to 30 months
  ahead. The expensive part is exposed as `nonisolated static` `computeMonth*` functions — pure,
  callable from a background thread since `Calendar`/`CalendarEngine` are value types and
  `DateFormatter`/`NumberFormatter` construction goes through SwiftCommons' thread-local
  `FormatterCache`. `prefetchMonth` itself is `nonisolated`; it checks which entries are already
  cached, computes only the missing ones off the main actor, and stores them in a single
  `MainActor.run` hop, so `CalendarRenderCache` stays a `@MainActor` class with synchronous reads
  for `body` while the expensive work runs elsewhere. Overlapping sweeps (one per month boundary
  crossed) therefore cost a lookup hop for already-warm months, not a recomputation.
  `MonthPrefetchCoordinator.cancel()` (called on `.onDisappear` and window resets) stops an
  in-flight sweep; previously warmed entries stay cached.
- Every cache `store` inserts into its eviction order list only when the key is new. Prefetch and
  the render path can finish the same entry concurrently; appending twice would grow the order list
  without bound and make eviction drop freshly re-stored entries ahead of genuinely old ones.
- **Never re-inject environment objects per row.** `CalendarView.body` injects the model, `Theme`,
  and `Typography` once; everything below inherits them. Each observable `.environment(_:)` call and
  each `@Environment(Type.self)` declaration instantiates a generic key path at runtime (with type
  demangling), so doing it per realized `LazyVStack` row was the single largest cost in a fast-scroll
  Animation Hitches profile (~1,150 of ~6,000 main-thread samples inside hitch windows). Views created
  per row (`VerticalMonthView`) take plain `let` inputs instead. Exception: `CalendarBodyHorizontalView`
  receives its model as a stored property (and is hosted that way in tests), so it must still inject
  the model into its (at most three) pages.
- **Vertical scroll settles only when idle.** `CalendarBodyVerticalView` writes the scrolled-to month
  to the model once, on the `.idle` scroll phase — never per month crossed mid-gesture or
  mid-momentum. A settlement's own model change must not be treated as external navigation
  (`ScrollSettleCoordinator.consumeSettledMonth`): the list has usually moved on by the time it
  arrives, and resetting the window then `scrollTo`s back and kills momentum (the "fling stops
  dead" bug). The scroll uses `.viewAligned(limitBehavior: .never)`; the default limit caps a fling
  to about one month in compact width.
- The vertical list measures its content width once and passes it to each row's `CalendarBodyView`
  as `layoutWidth`; rows must not measure themselves (a per-row `@State` write doubles the work of
  realizing a month during a fast scroll).
- **Vertical month window.** SwiftUI's lazy stack pays per-update bookkeeping (`ForEach` item walk,
  placement estimates, `scrollTo` index search) proportional to the *total* row count, not the
  visible rows. Profiling showed 3,001 rows (±1,500 months) produced ~94 interaction delays per
  fast-scroll session versus 2 at 241 rows. `VerticalMonthWindow` therefore realizes ±240 months
  around the anchor and re-centers (resets the anchor to the settled month) when the scroll rests
  60+ months from it and more allowed months exist beyond the window edge. Never grow the window
  by prepending rows mid-scroll — see the LazyVStack `.scrollPosition` note in project memory.
- **Date range.** `CalendarState.dateRange` (a `ClosedRange<Date>`, clamped to 1900–2100) is the
  single source of truth for navigable/selectable dates. It is carried into `CalendarEngine` as
  `supportedDates`, so every navigation, offset, picker, and paging check obeys it. Month-offset
  cache keys include those bounds (identical calendars with different ranges resolve offsets
  differently); geometry and titles do not depend on them. Day availability (`isEnabled`) is
  applied on read in `monthSnapshot(for:)`, per day via `CalendarEngine.availableDayStarts`.
- Render-cache lookups on the hot path pass `CalendarState.renderSignature` (computed once per
  calendar change) rather than a `Calendar`, so the signature string is not rebuilt per lookup.
- Keep per-day loops free of `Calendar` work. `CalendarSelection.matcher(in:)` normalizes a
  selection once for a whole grid; `CalendarEngine.supportedDates` is resolved once per time zone.
- In a `View`, mutating `@State` that only exists for bookkeeping invalidates the body. The vertical
  calendar keeps its scroll-settle counter in a reference type (`ScrollSettleCoordinator`) for that
  reason.

## Planning Workflow

Read and follow `DEVELOPMENT.md` before starting any task. It contains the planning checklist and required test-run matrix.

## Testing — Mandatory

All changes to `Sources/` require tests. `swift test` must pass before merge.

### Unit Tests (`Tests/.../Unit/`)
- Use `@Suite` + `@Test` (Swift Testing) — not XCTest `testXYZ`.
- Annotate `@Suite` struct with `@MainActor` (models are `@Observable`).
- Use `CalendarViewModel.test(identifier:selection:)` factory (defined in `CalendarViewModel.swift`).

### Structural Snapshot Tests (`Tests/.../Snapshot/`)
- Text (`.txt`) snapshots that serialize the state driving rendering — resolved month grid, selection
  roles, localization, layout direction, and the `CalendarGridLayout` math. No simulator, no pixel
  diffing; they render identically on every machine and OS, so a local `swift test` is authoritative.
- Required for any new or modified SwiftUI view or rendering-relevant model change.
- Use `CalendarViewModel.snapshot(identifier:selection:)` factory (defined in `SnapshotConfiguration.swift`, pins to June 1, 2025).
- Use `assertCalendarStructure(model:configuration:theme:width:monthSpan:named:)`; day-cell tests use
  `assertDayContextStructure(_:rendererFor:named:)`. Renderer lives in `CalendarStructureRenderer.swift`.
- **Recording flow**: `SNAPSHOT_RECORD_MODE=all swift test --filter Snapshot --traits TCA`, then run
  once more without the env var to verify. Commit the regenerated `.txt` files. Diffs are readable —
  review them.
- Genuine view-layer behavior (LazyVStack anchor recovery, hit targets, glass fallbacks) belongs in a
  hosted unit test under `Tests/.../Unit/`, not here.

### Coverage Requirements
| Area | Minimum |
|------|---------|
| Scroll modes (`.none`, `.vertical`, `.horizontal`) | Structural snapshot per mode |
| Day view types (`circle`, `square` renderers) | All context states |
| Calendar systems | Gregorian + Persian |
| `CalendarViewModel` public/internal methods | ≥ 1 positive + ≥ 1 edge case each |

## Commits & PRs

- Imperative subject line (`Add …`, `Fix …`). Don't mix formatting-only with feature changes.
- PRs: summary, linked issue, screenshots for UI changes, `swift test` output.
