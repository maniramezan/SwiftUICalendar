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
    } else {
      Color.clear
    }
  }

  private var strokeColor: Color {
    context.isToday ? dayTheme.todayBorderColor : Color.clear
  }

  var body: some View {
    ZStack {
      if context.isToday && !context.isSelected {
        Circle()
          .fill(Color.clear)
          .adaptiveGlass(shape: .circle, interactive: true, tint: dayTheme.todayBorderColor)
      } else {
        Circle()
          .fill(backgroundColor)
          .overlay(Circle().strokeBorder(strokeColor, lineWidth: dayTheme.todayBorderColorWidth))
      }
      Text(context.dayLabel)
        .font(dayTypography.primaryFont)
        .minimumScaleFactor(typography.minScaleFactor ?? 1.0)
    }
    .contentShape(Circle())
    .onTapGesture { context.onSelect(context.date) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(accessibilityTraits)
  }

  private var accessibilityLabel: String {
    var components = [context.date.formatted(date: .abbreviated, time: .omitted)]
    if context.isToday {
      components.append("Today")
    }
    if context.isSelected {
      components.append("Selected")
    }
    return components.joined(separator: ", ")
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
