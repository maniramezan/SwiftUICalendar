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

`SwiftCommons` (remote, branch `main`) and `SwiftUIComponents` (local path `../SwiftUIComponents`) must both be available. The sibling repo must live at `../SwiftUIComponents` relative to this checkout.

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
  Snapshot/      # Snapshot tests using swift-snapshot-testing
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

### Snapshot Tests (`Tests/.../Snapshot/`)
- Required for any new or modified SwiftUI view.
- Use `CalendarViewModel.snapshot(identifier:selection:)` factory (defined in `SnapshotConfiguration.swift`, pins to June 1, 2025).
- Use `assertCalendarSnapshot(of:width:height:named:)` helper for assertions.
- Views under test need these environment values: `vm`, `theme`, `Typography.default`, `\.locale`, `\.layoutDirection`.
- **Recording flow**: set `globalRecordMode = .all` in `SnapshotConfiguration.swift`, run tests, **revert to `.missing`**, commit `.png` reference images. Never merge with `.all`.
- Snapshot tests are macOS/iOS only.

### Coverage Requirements
| Area | Minimum |
|------|---------|
| Scroll modes (`.none`, `.vertical`, `.horizontal`) | Snapshot per mode |
| Day view types (`CircleDayView`, `SquareDualCalendarDayView`) | All visual states |
| Calendar systems | Gregorian + Persian |
| `CalendarViewModel` public/internal methods | ≥ 1 positive + ≥ 1 edge case each |

## Commits & PRs

- Imperative subject line (`Add …`, `Fix …`). Don't mix formatting-only with feature changes.
- PRs: summary, linked issue, screenshots for UI changes, `swift test` output.
