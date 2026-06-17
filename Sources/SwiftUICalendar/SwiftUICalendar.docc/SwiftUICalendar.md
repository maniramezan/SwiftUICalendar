# ``SwiftUICalendar``

Build configurable SwiftUI calendars with modern selection, scrolling, and alternate calendar support.

@Options {
    @AutomaticSeeAlso(disabled)
}

## Overview

SwiftUICalendar provides a SwiftUI-first calendar component for apps that need more than a static month grid. The package includes a stateful `CalendarViewModel`, a composable `CalendarView`, built-in day renderers, and theme and typography models that can be customized without forking the view implementation.

### Normal

![Normal SwiftUICalendar view](calendar-normal)

### Horizontal

![Horizontal SwiftUICalendar view](calendar-horizontal)

### Vertical

![Vertical SwiftUICalendar view](calendar-vertical)

Use the package when you need:

- Single-date, range, or multiple-date selection.
- Gregorian, Persian, Hebrew, Islamic, Chinese, Japanese, or other Foundation calendar identifiers.
- Fixed, vertical scrolling, or horizontal paging layouts.
- Custom day cells with app-specific color, typography, and secondary labels.
- Snapshot-testable SwiftUI rendering.

## Quick Start

Create a view model, keep it in SwiftUI state, and pass it to `CalendarView`.

```swift
import SwiftUI
import SwiftUICalendar

struct BookingCalendar: View {
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

## Customize Layout

`Theme` controls how the calendar scrolls and how days are rendered.

```swift
let theme = Theme()
theme.scrollMode = .horizontal
theme.horizontalHeightMode = .hugContent
theme.day.selectedBackgroundColor = .indigo

CalendarView(model: calendar, theme: theme)
```

## Add Secondary Calendar Labels

Use `Theme.Day.useSquareDualCalendarDayView(secondaryLabel:)` when your UI needs to show the primary calendar and an alternate calendar at the same time.

```swift
let theme = Theme()
theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)

CalendarView(model: calendar, theme: theme)
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:BuildingACalendarScreen>
- ``CalendarView``
- ``CalendarViewModel``
- ``CalendarViewModel/Selection``

### Appearance

- ``Theme``
- ``Theme/ScrollMode``
- ``Theme/HorizontalHeightMode``
- ``Theme/Day``
- ``Theme/Day/SecondaryLabelMode``
- ``Typography``
- ``DayViewTypography``
- ``DayViewType``

### Custom Day Views

- <doc:CustomizingDayViews>
- ``CalendarDayContext``
- ``CalendarDayView``

### Tutorials

- <doc:SwiftUICalendarTutorials>
