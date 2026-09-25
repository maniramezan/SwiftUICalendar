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

Reading the hinge from the system needs a newer SDK: `GeometryProxy.reservedRegions(kind: .division)`
arrives in the iOS 27.1 SDK. The calendar calls it whenever it is *built* with that SDK or newer, and
compiles the call out otherwise, so the package still builds with Xcode 27.0.

- **Built with Xcode 27.1 or later**, on iOS 27.1 or later: the calendar reads the hinge itself and
  moves clear of it. Nothing to adopt.
- **Built with Xcode 27.0**, or running on an earlier iOS: no hinge is reported, and the calendar lays
  out exactly as it does on any other iPhone.

Swift has no SDK-version conditional, and Xcode 27.0 and 27.1 ship the same compiler, but their
SwiftUICore modules differ in version, which `canImport(SwiftUICore, _version:)` can test. That is the
gate; `#available(iOS 27.1, *)` then guards older devices at run time.

To ship Duo support in your app, build it with Xcode 27.1 or later.
