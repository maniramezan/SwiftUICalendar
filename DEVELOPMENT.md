# Planning & Testing Playbook

## Planning Checklist
- Confirm scope and impacted areas (Package sources/tests, sample app, tooling).
- List the files or folders to touch before editing.
- Decide which tests/builds to run based on the change area.
- Call out missing tests or assumptions in the final response.

## Build, Test, and Development Commands
- Run `swift package resolve` when the sibling packages `../SwiftCommons` and `../SwiftUIComponents` change.
- Use `swift build -c debug` for quick package builds.
- Use `swift test` for all package-level test targets.
- Use `swift run SwiftUICalendar` for ad-hoc previews or CLI diagnostics when adding executable entry points.

## Testing Guidelines

### Framework
- Use Swift Testing (`import Testing`, `@Test`, `@Suite`) for all new tests.
- Existing XCTest cases in `SwiftUICalendarTests.swift` remain valid; do not remove them.
- All test suites must be decorated `@MainActor` (models are `@Observable`).
- Use `CalendarViewModel.test(identifier:selection:)` for unit tests.
- Use `CalendarViewModel.snapshot(identifier:selection:)` (pins to June 1 2025) for snapshot tests.

### Mandatory Coverage Policy
Every PR that touches `Sources/` MUST include corresponding tests:
- **Logic change** → at least one `@Test` in `Tests/SwiftUICalendarTests/Unit/`.
- **New/changed view** → at least one snapshot test updated or added in `Tests/SwiftUICalendarTests/Snapshot/`.
- **New public API method** → positive case + edge/nil case.

### Snapshot Tests
- Reference images stored in `Tests/SwiftUICalendarTests/Snapshot/__Snapshots__/`.
- To record: set `globalRecordMode = .all` in `SnapshotConfiguration.swift`, run tests, **revert to `.missing`**, commit reference images alongside code.
- Never commit with `globalRecordMode = .all`.

### Required Test Scenarios per PR
1. Cover the affected scroll mode (`.none` / `.vertical` / `.horizontal`)
2. Cover Gregorian + at least one non-Gregorian calendar if calendar logic is touched
3. Cover the affected selection mode (`single` / `range` / `multiple`)

### Commands
```bash
swift package resolve         # after Package.swift changes
swift build -c debug          # quick compile check
swift test                    # all tests
MINIMUM_COVERAGE=80 bash ./scripts/check-coverage.sh
swift test --filter CalendarViewModel  # model logic tests only
swift test --filter Snapshot  # snapshot tests only
bash ./scripts/build-docs.sh  # build static DocC output
```

## Release Checklist
- Confirm `README.md` installation examples point at the current release tag.
- Run `bash ./scripts/lint.sh`, `swift build -c debug`, `swift test`, `MINIMUM_COVERAGE=80 bash ./scripts/check-coverage.sh`, and `bash ./scripts/build-docs.sh`.
- Create a GitHub release for the tag, for example `1.0.0`, and use GitHub Releases for release notes.

## Required Test Runs
- Package changes (`Sources/`, `Tests/`, `Package.swift`, or shared resources): run `swift test`.
- Sample app changes (`Examples/SwiftUICalendarSample`): run the sample tests via Xcode build tooling (prefer `xcodebuild test`; fall back to `xcodebuild build` if no test scheme exists).
- Cross-cutting changes: run both the package tests and the sample app build/tests.
