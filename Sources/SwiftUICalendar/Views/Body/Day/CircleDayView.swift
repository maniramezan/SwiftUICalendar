import SwiftUI

struct CircleDayView: CalendarDayView {
  private let context: CalendarDayContext

  init(context: CalendarDayContext) {
    self.context = context
  }

  private var dayTheme: Theme.Day {
    context.theme
  }

  private var typography: Typography {
    context.typography
  }

  private var dayTypography: DayViewTypography {
    typography.dayViewTypography(for: DayViewType.circle)
  }

  private var backgroundColor: Color {
    if context.isSelected {
      dayTheme.selectedBackgroundColor
    } else if context.isToday {
      dayTheme.todayBackgroundColor
    } else if !context.isInCurrentMonth {
      dayTheme.emptyDayBackgroundColor
    } else {
      Color.clear
    }
  }

  private var strokeColor: Color {
    if context.isToday {
      dayTheme.todayBorderColor
    } else if !context.isInCurrentMonth {
      dayTheme.emptyDayBorderColor
    } else {
      Color.clear
    }
  }

  private var strokeWidth: CGFloat {
    if context.isToday {
      dayTheme.todayBorderColorWidth
    } else if !context.isInCurrentMonth {
      dayTheme.emptyDayBorderColorWidth
    } else {
      0
    }
  }

  var body: some View {
    Button {
      context.onSelect(context.date)
    } label: {
      ZStack {
        if context.isToday && !context.isSelected {
          Circle()
            .fill(Color.clear)
            .adaptiveGlass(shape: .circle, interactive: true, tint: dayTheme.todayBorderColor)
        } else {
          Circle()
            .fill(backgroundColor)
            .overlay(Circle().strokeBorder(strokeColor, lineWidth: strokeWidth))
        }
        Text(context.dayLabel)
          .font(dayTypography.primaryFont)
          .minimumScaleFactor(typography.minScaleFactor ?? 1.0)
      }
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(context.accessibilityLabel)
    .accessibilityAddTraits(accessibilityTraits)
  }

  private var accessibilityTraits: AccessibilityTraits {
    if context.isSelected {
      return [.isButton, .isSelected]
    }
    return .isButton
  }
}

#Preview {
  let context = CalendarDayContext(
    date: .now,
    day: 1,
    dayLabel: "1",
    isToday: true,
    isSelected: false,
    isInCurrentMonth: true,
    theme: Theme.default.day,
    typography: Typography.default,
    onSelect: { _ in print("Day selected") }
  )
  return CircleDayView(context: context)
    .environment(Theme.default)
    .environment(Typography.default)
}

#Preview("Empty Day") {
  let context = CalendarDayContext(
    date: .now,
    day: 28,
    dayLabel: "28",
    isToday: false,
    isSelected: false,
    isInCurrentMonth: false,
    theme: Theme.default.day,
    typography: Typography.default,
    onSelect: { _ in }
  )
  return CircleDayView(context: context)
    .environment(Theme.default)
    .environment(Typography.default)
}
