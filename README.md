# SwiftUICalendar

[![Build](https://img.shields.io/github/actions/workflow/status/maniramezan/SwiftUICalendar/build.yml?branch=main&label=build&style=flat-square)](https://github.com/maniramezan/SwiftUICalendar/actions/workflows/build.yml)
[![Swift](https://img.shields.io/badge/Swift-6.2-orange?style=flat-square&logo=swift)](https://www.swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%2018%20%7C%20macOS%2015-lightgrey?style=flat-square)](Package.swift)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen?style=flat-square)](https://swift.org/package-manager/)
[![Documentation](https://img.shields.io/badge/DocC-GitHub%20Pages-blue?style=flat-square)](https://maniramezan.github.io/SwiftUICalendar/documentation/swiftuicalendar/)

SwiftUICalendar is a SwiftUI calendar package with single, range, and multiple selection modes, built-in Gregorian and non-Gregorian calendar support, configurable scrolling, and customizable day rendering.

## Calendar Modes

These images are generated from the package snapshot references for the actual `CalendarView`.

| Normal | Horizontal | Vertical |
| --- | --- | --- |
| ![Normal SwiftUICalendar view](Sources/SwiftUICalendar/SwiftUICalendar.docc/Resources/calendar-normal.png) | ![Horizontal SwiftUICalendar view](Sources/SwiftUICalendar/SwiftUICalendar.docc/Resources/calendar-horizontal.png) | ![Vertical SwiftUICalendar view](Sources/SwiftUICalendar/SwiftUICalendar.docc/Resources/calendar-vertical.png) |

## Requirements

- Swift 6.2+
- iOS 18+
- macOS 15+

## Installation

Add SwiftUICalendar with Swift Package Manager:

```swift
.package(url: "https://github.com/maniramezan/SwiftUICalendar.git", from: "1.0.0")
```

Then add the product to your target:

```swift
.product(name: "SwiftUICalendar", package: "SwiftUICalendar")
```

## Quick Start

```swift
import SwiftUI
import SwiftUICalendar

struct BookingView: View {
    @State private var calendar = CalendarViewModel(
        calendarIdentifier: .gregorian,
        selection: .range(nil, nil)
    )

    var body: some View {
        CalendarView(model: calendar)
            .frame(minHeight: 420)
    }
}
```

## Selection Modes

```swift
CalendarViewModel(calendarIdentifier: .gregorian, selection: .single(nil))
CalendarViewModel(calendarIdentifier: .gregorian, selection: .range(nil, nil))
CalendarViewModel(calendarIdentifier: .gregorian, selection: .multiple([]))
```

`selection` is mutable, so screens can read or replace it after user interaction:

```swift
switch calendar.selection {
case .single(let date):
    print(date as Any)
case .range(let start, let end):
    print(start as Any, end as Any)
case .multiple(let dates):
    print(dates)
}
```

## Theming

```swift
let theme = Theme()
theme.day.selectedBackgroundColor = .indigo
theme.day.todayBorderColor = .orange

let configuration = CalendarConfiguration(
    scrollMode: .horizontal,
    horizontalHeightMode: .hugContent
)

CalendarView(model: calendar, theme: theme, configuration: configuration)
```

## Alternate Calendar Labels

Use the square dual-calendar day view to show a secondary day number from another calendar system:

```swift
let theme = Theme()
theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)

CalendarView(
    model: CalendarViewModel(calendarIdentifier: .gregorian),
    theme: theme
)
```

## Right-to-Left Support

Calendars whose native script reads right-to-left — Persian, Hebrew, and the Islamic
variants — automatically render with a mirrored, right-to-left layout, even on a left-to-right
system locale. Gregorian and other left-to-right calendars are unaffected.

```swift
CalendarView(model: CalendarViewModel(calendarIdentifier: .hebrew))
```

## Documentation

Build DocC locally:

```bash
bash ./scripts/build-docs.sh
```

The generated static documentation is written to `.build/docs`. CI validates DocC on pull requests and publishes the same output to GitHub Pages on pushes to `main`.

## Versioning

SwiftUICalendar follows semantic versioning for tagged releases, starting at `1.0.0`. Source-breaking API changes only ship in major versions.

## Development

```bash
swift package resolve
swift build -c debug
swift test
MINIMUM_COVERAGE=80 bash ./scripts/check-coverage.sh
bash ./scripts/build-docs.sh
```

Snapshot references live in `Tests/SwiftUICalendarTests/Snapshot/__Snapshots__`. When recording snapshots, set `globalRecordMode = .all`, run the snapshot tests, then revert to `.missing` before committing.

## License

SwiftUICalendar is available under the MIT license. See [LICENSE](LICENSE) for details.
