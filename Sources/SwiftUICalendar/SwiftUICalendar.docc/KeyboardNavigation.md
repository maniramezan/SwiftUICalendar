# Keyboard Navigation

Browse and select dates from a hardware keyboard, and decide which shortcuts the calendar consumes.

## Overview

A calendar on iPad with a Magic Keyboard, or on macOS, is expected to respond to the arrow keys. Give
the calendar keyboard focus and it draws a *focus ring* around one day — the keyboard cursor — which
moves independently of the current selection. Nothing is selected until the reader asks for it, so
arrowing across a month never disturbs a range the reader already built.

| Key | Action |
| --- | --- |
| `←` `→` | Move the cursor one day, following the calendar's layout direction |
| `↑` `↓` | Move the cursor one week |
| `Return` `Space` | Select the focused day using the current selection mode |
| `⌘←` `⌘→` | Move to the previous or next month |
| `⌘T` | Return to today, when today is inside ``CalendarViewModel/dateRange`` |

Horizontal keys follow the layout direction, so in a right-to-left calendar such as Persian or Hebrew
`→` moves to the *earlier* day and `⌘←` advances a month. Movement stops at the edges of
``CalendarViewModel/dateRange`` rather than clamping silently, and the cursor scrolls itself into view
in the scrolling layouts.

## Choosing Which Shortcuts Apply

The calendar handles these keys only while it holds focus, but a host app may already own some of
them — `⌘T` opens a new tab in many document apps. Narrow
``CalendarConfiguration/keyboardNavigation`` to hand those back:

```swift
// Arrow-key browsing and month paging, but leave ⌘T to the app.
let configuration = CalendarConfiguration(
    keyboardNavigation: [.arrows, .monthShortcuts]
)

CalendarView(model: calendar, configuration: configuration)
```

Pass an empty set to opt out entirely. The calendar then stops being a keyboard focus target, so it
no longer appears as a tab stop:

```swift
CalendarConfiguration(keyboardNavigation: [])
```

A shortcut the calendar declines — `⌘T` when today falls outside the date range, or `→` on the last
selectable day — is reported as unhandled, so the host app and the system still see the key press.

## Styling the Focus Ring

The ring is drawn from ``Theme/Day/focusBorderColor`` and ``Theme/Day/focusBorderWidth``, which work
the same way as the outline for today:

```swift
let theme = Theme()
theme.day.focusBorderColor = .orange
theme.day.focusBorderWidth = 2

CalendarView(model: calendar, theme: theme)
```

Because the ring marks keyboard focus rather than content, it is hidden from assistive technologies
and never intercepts touches or clicks.

## Topics

### Configuration

- ``CalendarConfiguration/KeyboardNavigation``
- ``CalendarConfiguration/keyboardNavigation``

### Appearance

- ``Theme/Day/focusBorderColor``
- ``Theme/Day/focusBorderWidth``
