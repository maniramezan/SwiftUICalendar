# Adapting to iPhone Duo

How the calendar uses each half of a folding display while keeping complete weeks readable.

## Overview

`CalendarView` adapts to the space its host provides. Closed and fully open displays use the normal
calendar presentation. An active fold can present two consecutive months, with each month contained
in its own panel. Your app continues to use one model, selection, theme, and configuration.

The layout reads the fold's full rectangle in the calendar viewport's coordinate space. It does not
infer posture from interface orientation, device names, or a fixed hinge angle. A calendar hosted
entirely on one side of a fold keeps its normal presentation.

## Book and Tabletop Layouts

With a vertical fold, the visible month occupies the leading panel and the following month occupies
the trailing panel. Right-to-left calendars, including Persian and Hebrew, place the visible month
on the physical right and the following month on the left.

With a horizontal fold, the visible month occupies the upper panel and the following month occupies
the lower panel. Both panels retain the calendar's reading direction. Each month has its own vertical
scrolling, so shorter panels keep every week reachable.

The primary panel retains fixed or horizontal month paging. While two panels are visible, vertical
mode shows a single month in its primary panel instead of repeating the companion month in a
continuous list; use the navigation header to change the spread. Each month still scrolls vertically
when its weeks exceed the panel height. The companion presents the following month as a fixed
month. Navigating the primary month updates the companion to match. Both panels use the same
selection, including ranges that cross the month boundary, and the same custom day renderer. Overflow days are hidden while the companion is visible
to avoid presenting the same dates in both panels.

Folding, rotating the fold, and unfolding keep the primary viewport mounted. These layout changes do
not navigate the model or clear its selection.

## Small Panels and Date Bounds

Two months appear only when both panels meet the readable width and minimum useful height resolved
from the calendar's content metrics. Larger text or a custom day view's declared minimum can require
more room. If either panel is too small, the calendar uses the largest usable panel. Equal panels
prefer the leading side for a vertical fold and the upper side for a horizontal fold.

A narrow single panel scrolls horizontally to expose every column without reducing day cells below
their readable minimum or the 44-point touch target. Short panels scroll vertically to expose every
week and the navigation header. See <doc:GettingStarted> for the sizing rules.

The companion respects `CalendarState.dateRange`. At the last allowed month, the calendar uses one
panel instead of duplicating the current month or showing a month outside the allowed range.

## Requirements

The fold layout itself supports the package's minimum deployment targets, iOS 18 and macOS 15.
Reading the system's fold geometry requires Xcode 27.1 or later and iOS 27.1 or later.

`GeometryProxy.reservedRegions(kind: .division)` is compiled only when
`canImport(SwiftUICore, _version: 8.0.85)` succeeds and is guarded by a runtime availability check.
Older toolchains and operating systems keep the normal calendar layout.

For app-level arrangements such as a calendar beside an agenda, use Apple's
[ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview) outside the
calendar. See [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
for system containers and reserved regions.
