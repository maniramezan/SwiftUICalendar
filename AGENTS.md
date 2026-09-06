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
