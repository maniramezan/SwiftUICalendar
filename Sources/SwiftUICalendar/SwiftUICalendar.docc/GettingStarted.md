# Getting Started

Install SwiftUICalendar and render your first calendar.

## Add the Package

Add the package in Xcode or in `Package.swift`:

```swift
.package(url: "https://github.com/maniramezan/SwiftUICalendar.git", branch: "main")
```

Then link the product:

```swift
.product(name: "SwiftUICalendar", package: "SwiftUICalendar")
```

## Render a Calendar

```swift
import SwiftUI
import SwiftUICalendar

struct CalendarDemo: View {
    @State private var calendar = CalendarViewModel(calendarIdentifier: .gregorian)

    var body: some View {
        CalendarView(model: calendar)
            .frame(minHeight: 420)
    }
}
```

## Choose a Selection Mode

Use ``CalendarViewModel/Selection`` to decide how users select dates.

```swift
@State private var single = CalendarViewModel(
    calendarIdentifier: .gregorian,
    selection: .single(nil)
)

@State private var range = CalendarViewModel(
    calendarIdentifier: .gregorian,
    selection: .range(nil, nil)
)

@State private var multiple = CalendarViewModel(
    calendarIdentifier: .gregorian,
    selection: .multiple([])
)
```

## Switch Calendars

`Date` values are calendar independent, so existing selections survive a calendar-system switch.

```swift
Picker("Calendar", selection: $calendarIdentifier) {
    Text("Gregorian").tag(Calendar.Identifier.gregorian)
    Text("Persian").tag(Calendar.Identifier.persian)
    Text("Hebrew").tag(Calendar.Identifier.hebrew)
}
.onChange(of: calendarIdentifier) { _, identifier in
    calendar.updateCalendar(identifier: identifier)
}
```
