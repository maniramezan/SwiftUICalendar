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

Reading the hinge from the system needs a newer SDK. `GeometryProxy.reservedRegions(kind: .division)`
is declared `@available(anyAppleOS 27.1, *)` and does not exist in the 27.0 SDKs. The call is wrapped in
`#if canImport(SwiftUICore, _version: 8.0.85)`, so older toolchains compile the call out and keep
building.

- **Built with Xcode 27.1 or later**, on iOS 27.1 or later: the calendar reads the hinge itself and
  moves clear of it. Nothing to adopt.
- **Built with Xcode 27.0**, or running on an earlier OS: no hinge is reported, and the calendar lays
  out exactly as it does on any other iPhone.

Inside the compile-time gate, a runtime `#available(iOS 27.1, macOS 27.1, *)` check guards older
devices. The version in `canImport` is required: a bare `#if canImport(SwiftUICore)` succeeds on
every SDK back to iOS 18, so it cannot tell 27.0 from 27.1.

To ship Duo support in your app, build it with Xcode 27.1 or later.
