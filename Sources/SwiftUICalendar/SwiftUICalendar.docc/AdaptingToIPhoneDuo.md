# Adapting to iPhone Duo

How the calendar behaves on a folding display, and what it needs from your app.

## Overview

On iPhone Duo the outer display behaves like any other iPhone, while the inner display is regular in
both size classes. The inner display does not honor supported interface orientations, so the calendar
makes every layout decision from size classes and available width rather than from orientation — which
is what it already did for iPad and resizable macOS windows.

Nothing in your app needs to change. `CalendarView` adapts on its own.

## Staying Clear of the Fold

When the device is partially folded, the hinge crosses the inner display and the system reports a
*division* reserved region covering that band. Content spanning the band is harder to read, and a day
cell landing in it is hard to tap.

Rather than straddle the fold, the calendar **displaces** itself: it measures the division regions in
its own coordinate space and lays the grid out in the widest band beside them. A week still reads as a
single row, and day cells keep their full touch targets.

If the chosen band is narrower than the grid's minimum width — seven minimum-size cells plus their
spacing — the calendar falls back to the same behavior it uses in any narrow window: the band scrolls
horizontally so every date stays reachable, instead of shrinking cells below the minimum hit target.
See <doc:GettingStarted> for the sizing rules this builds on.

Right-to-left calendars — Persian, Hebrew, Islamic — land on the correct side of the fold too:
the fold is measured where the hinge physically is, and the calendar converts it to its own
layout direction before choosing a band.

Equally wide bands resolve to the leading one, so a symmetrically folded device does not flip the
calendar from side to side as the hinge angle wobbles.

## Requirements

The displacement itself needs nothing newer than the package's own minimum, iOS 18 / macOS 15, and is
active on every platform.

What *does* need a newer SDK is reading the hinge from the system.
`GeometryProxy.reservedRegions(kind: .division)` arrives in the iOS 27.1 SDK, and Swift has no way to
compile conditionally on SDK version, so referencing it would make Xcode 27.1 a hard requirement for
building the package at all.

The fold source is therefore injected rather than called inline. The layout reads blocked bands from
the `calendarFoldRanges` environment value, which means the behavior is complete and testable today,
and connecting it to the system is one availability-gated line once the toolchain moves:

```swift
// Added when the project builds against the iOS 27.1 SDK.
.onGeometryChange(for: [ClosedRange<CGFloat>].self) { proxy in
    guard #available(iOS 27.1, *) else { return [] }
    // `.fixed`: the calendar expects physical coordinates and handles right-to-left itself.
    return proxy.reservedRegions(kind: .division, layoutDirectionBehavior: .fixed)
        .filter(\.isActive)
        .map { $0.frame.minX...$0.frame.maxX }
} action: { ranges in
    foldRanges = ranges
}
```

Until then the calendar renders exactly as it always has on an unfolded display, because an empty set
of blocked bands resolves to no displacement.
