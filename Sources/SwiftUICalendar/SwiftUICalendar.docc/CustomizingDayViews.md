# Customizing Day Views

Replace built-in day cells with a custom SwiftUI renderer.

## Use the Context

Custom day views conform to ``CalendarDayView`` and receive a ``CalendarDayContext``.

```swift
struct EventDayView: CalendarDayView {
    let context: CalendarDayContext

    init(context: CalendarDayContext) {
        self.context = context
    }

    var body: some View {
        Button { context.onSelect(context.date) } label: {
          VStack(spacing: 4) {
            Text(context.dayLabel)
                .font(context.typography.dayFont)

            if context.isSelected {
                Circle()
                    .fill(.blue)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(context.accessibilityLabel)
        .accessibilityAddTraits(context.isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
```

## Fit Your Cell

The calendar gives every day view one rectangle, ``CalendarDayContext/cellSize``, and proposes exactly
that size. Neither side is smaller than the 44pt touch target; the width grows with the grid on wide
windows, and every cell on screen is the same size. A day view that ignores it overflows
into its neighbors or leaves a gap, and on a narrow phone every point counts: seven columns of 44pt
cells already fill an iPhone SE.

- **Fill the proposal.** Use `.frame(maxWidth: .infinity, maxHeight: .infinity)` and let the calendar
  size the cell. Never hardcode `.frame(width: 44, height: 44)`, and do not add your own minimum
  height; the cell is already at the touch-target floor.
- **Read `cellSize`, not a `GeometryReader`.** Scale emoji, dots, and padding from it
  (`context.cellSize.width * 0.4`). A `GeometryReader` adds a layout pass to every cell and a month holds
  up to 42 of them.
- **Shed detail before you overflow.** At the minimum size there is room for a number and one small
  mark. Show extra marks, secondary labels, or a second row only when `cellSize` allows, and cap what
  you show (`lineLimit(1)`, `minimumScaleFactor`, a maximum of a few glyphs).
- **Keep the cell the hit target.** Make the whole cell tappable with `.contentShape(Rectangle())`
  rather than growing the visible content.
- **Let text scale, but contain it.** Use semantic fonts (`context.typography.dayFont`) so text
  follows Dynamic Type, and give the label `minimumScaleFactor` so a large setting shrinks it back
  into the cell instead of clipping. Do not scale the frame itself with Dynamic Type; the calendar
  owns row sizing.
- **Clip what you draw outside the cell.** Shadows and badges that spill past the cell overlap
  the next day; apply `.clipped()` or keep them inside.

## Register the View

```swift
let theme = Theme()
theme.day.setDayContent { context in
    EventDayView(context: context)
}

CalendarView(model: calendar, theme: theme)
```

## Add Secondary Labels

If your custom day cell supports secondary labels, read `context.secondaryLabel` and configure the theme with a built-in or custom label mode.

```swift
theme.day.secondaryLabelMode = .calendar(.hebrew)
theme.day.secondaryLabelMode = .custom { date in
    formatter.string(from: date)
}
```

## Accessibility Checklist

Custom day cells should:

- Expose one accessibility element per selectable date.
- Include the formatted date in the label.
- Include selected and today state when relevant.
- Use button semantics or an actual `Button`.
- Call `context.onSelect(context.date)` for activation.
