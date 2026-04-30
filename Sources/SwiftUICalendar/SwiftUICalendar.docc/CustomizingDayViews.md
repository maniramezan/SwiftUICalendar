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
        VStack(spacing: 4) {
            Text(context.dayLabel)
                .font(context.typography.dayFont)

            if context.isSelected {
                Circle()
                    .fill(.blue)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { context.onSelect(context.date) }
        .accessibilityLabel(context.date.formatted(date: .abbreviated, time: .omitted))
        .accessibilityAddTraits(context.isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
```

## Register the View

```swift
let theme = Theme()
theme.day.dayContent = { context in
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
