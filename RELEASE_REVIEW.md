# 0.1.0 release readiness

Updated September 5, 2026 after implementing the review fixes. Implementation and local validation are complete; CI snapshot verification and manual accessibility checks remain release gates.

## Implemented fixes

| Finding | Resolution |
| --- | --- |
| Era/leap-month identity loss | `MonthIdentifier` includes calendar, era, year, month, and leap-month status. Foundation month intervals drive grids and navigation. Chinese leap months have distinct picker entries. Historical Japanese days retain their actual dates. |
| Vertical calendar switching | Switching calendar identity resets the mounted vertical view's anchor, offsets, interaction state, and scroll position. Mounted Gregorian → Persian → Gregorian snapshots exercise this path. |
| Snapshots skipped by default | Ordinary `swift test` compares references. An explicit `SNAPSHOT_ASSERTIONS=false` disables suites visibly. PR CI compares snapshots before merge. A regression test proves different pixels fail. |
| Inconsistent supported years | A single Gregorian 1900–2100 interval drives arithmetic. Partially supported months remain navigable. Numeric year/month navigation stays in the visible era, including January 8, 1989 and May 1, 2019 transitions; relative navigation crosses eras. |
| Stale documentation | Installation uses 0.1.0; 0.x compatibility policy, dependency instructions, public navigation examples, custom controls, and theme examples are corrected. A consumer fixture compiles without `@testable`. |
| Gesture-only day controls | Both built-in cells and custom-cell examples use native plain Buttons while retaining date descriptions and selected traits. |
| Spoken dates ignored calendar context | `CalendarDayContext` carries the calendar/locale/time zone and provides a shared accessibility description. Tests verify Persian year 1404 on an English locale. Status strings use that locale with the catalog's English fallback. |
| Reduce Motion ignored | Horizontal paging and snap-back disable spring animations when Reduce Motion is enabled. A rendered regression covers the reduced-motion configuration. |

Additional release fixes:

- DocC now uses SwiftPM symbol graph generation and `docc convert`, with warnings treated as errors. The former root-directory `xcodebuild docbuild` failed in this environment.
- Generated `.strings` resources make localization work when SwiftPM copies rather than compiles `.xcstrings`. Lint checks generated resources against the catalog.
- The macOS snapshot comparator retains exact pixel comparison but avoids the snapshot dependency's failing Core Image diagnostic renderer. Actual and reference PNG attachments remain available.
- Snapshot references use a fixed light appearance and white background; README/DocC images are refreshed from those references.
- CI pins Xcode 26.3 on macos-15, enforces the documented 80% coverage threshold, compiles consumer examples, and builds the iOS sample.
- Invalid date components fail instead of silently rolling into another month; a zero-month offset preserves the original instant.

## Architecture

The existing MVVM entry point, `CalendarView(model:)`, is preserved. Foundation arithmetic lives in `Domain/CalendarEngine.swift`; selection is a Sendable `CalendarSelection` value with independent transition rules. `CalendarViewModel.Selection` remains an alias. The observable model owns state and derives presentation snapshots; view-local scrolling state remains in SwiftUI.

The optional `TCA` trait adds `SwiftUICalendarTCA`, `CalendarFeature`, and `TCACalendarView`.
Both MVVM and the reducer use atomic `CalendarState` transitions. Controlled rendering forwards
`CalendarAction` intents without mutating a presentation copy. Reducer state contains only value
state; Today uses TCA's injectable clock. See the Architecture article for dependency/toolchain
constraints and delegate actions.

## Review-fix validation (commit 7228276)

Environment: macOS 27.0 beta (26A5425a), Xcode 27.0 beta (27A5252f), Swift 6.4.

- Full package run: **284 tests in 34 suites passed**, including actual snapshot comparisons and mounted calendar switching.
- Required coverage script: **84.25%** (2043/2425 lines as calculated by the repository script); all tests in that coverage run passed.
- Swift formatting and generated localization checks: passed.
- Public consumer example type-check: passed.
- DocC generation with warnings as errors: passed.
- `git diff --check`: passed.
- Representative rendered calendar and switching snapshots were visually inspected.

Full-access validation resolved and tested the committed dependency versions: SwiftCommons 0.3.1, SwiftUIComponents 0.6.0, and SnapshotTesting 1.19.4. The local beta SwiftPM invocation still uses `--disable-sandbox --skip-update --cache-path /tmp/swiftuicalendar-spm-cache` with `CLANG_MODULE_CACHE_PATH=/tmp/swiftuicalendar-module-cache` to avoid a planning hang. Snapshots were refreshed at the host display's 2× scale and then compared successfully.

The iOS simulator sample builds successfully, and all four rotation/scroll UI tests pass on iPhone 17 Pro / iOS 27. Rotation tests now query full month names and the current month instead of hard-coded July abbreviations.

## Remaining release gates

1. **Compare/regenerate snapshots on CI's pinned OS and Xcode.** The refreshed PNGs were recorded and then successfully compared on the local beta toolchain. SwiftUI/AppKit snapshots are OS/SDK sensitive; this is not evidence that macos-15/Xcode 26.3 comparisons pass. Use the existing recording workflow, review the resulting images, and rerun PR checks before merge. Recording defaults remain `.missing`; `.all` was used only through the recording environment variable.
2. **Manually verify keyboard focus/activation and VoiceOver.** Native button semantics and spoken formatting are implemented; end-to-end assistive-technology behavior has not been certified by the local package tests.
3. **Install the candidate tag from a fresh consumer checkout.** Consumer source compilation passed, and network dependency resolution passed; the candidate tag has not been created yet.

This report accompanies the review-fix commit. No tag, PR, or release has been created.

## TCA implementation validation

- TCA-enabled compilation and exhaustive reducer tests passed on Swift 6.4 with TCA 1.26.2.
- The shared-state refactor passed the existing 284 tests with the trait disabled.
- Controlled rendering snapshots cover Gregorian/Persian and all scroll modes, including a mounted store update.
- Visual inspection exposed a collapsing macOS year-menu label; its intrinsic width and header spacing are now fixed. References were refreshed after this change.
- Final coverage, simulator, and fresh-consumer runs were stopped at the user's request; the user will run remaining validation. The Swift 6.2/TCA 1.25.5 branch still needs CI validation.
- Formatting was applied and `git diff --check` passed. No final post-header-change full-suite pass is claimed.

Before release, run:

```bash
swift test
swift test --traits TCA
MINIMUM_COVERAGE=80 bash scripts/check-coverage.sh --traits TCA
bash scripts/lint.sh
bash scripts/check-examples.sh
bash scripts/build-docs.sh
```

Also rerun the sample simulator tests and CI's pinned-toolchain snapshots. TCA remains disabled by default.
