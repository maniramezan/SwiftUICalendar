import SwiftUI

struct SquareDualCalendarDayView: CalendarDayView {
  private let context: CalendarDayContext
  private let cornerRadius: CGFloat = 8
  private let outerPadding: CGFloat = 4

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
    typography.dayViewTypography(for: DayViewType.squareDual)
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

  private var borderColor: Color {
    if context.isToday {
      return dayTheme.todayBorderColor
    }
    return context.isInCurrentMonth ? .clear : dayTheme.emptyDayBorderColor
  }

  private var borderWidth: CGFloat {
    if context.isToday {
      return dayTheme.todayBorderColorWidth
    }
    return context.isInCurrentMonth ? 0 : dayTheme.emptyDayBorderColorWidth
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(backgroundColor)
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(outerPadding)

      VStack(alignment: .leading, spacing: 2) {
        Text(context.dayLabel)
          .font(dayTypography.primaryFont)
          .minimumScaleFactor(typography.minScaleFactor ?? 1.0)

        Spacer()

        if let secondaryLabel = context.secondaryLabel {
          Text(secondaryLabel)
            .font(dayTypography.secondaryFont)
            .minimumScaleFactor(typography.minScaleFactor ?? 1.0)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .contentShape(Rectangle())
    .onTapGesture {
      context.onSelect(context.date)
    }
    .accessibilityLabel(context.accessibilityLabel(includeSecondaryLabel: true))
  }
}

#Preview("Square Dual Calendar") {
  // Configure theme with Persian secondary labels using new enum-based API
  let theme = Theme()
  theme.day.useSquareDualCalendarDayView(secondaryLabel: .persian)

  let context = CalendarDayContext(
    date: .now,
    day: 12,
    dayLabel: "12",
    isToday: true,
    isSelected: false,
    isInCurrentMonth: true,
    theme: theme.day,
    typography: Typography.default,
    onSelect: { _ in },
    secondaryLabel: theme.day.secondaryLabelMode.label(for: .now)
  )
  return SquareDualCalendarDayView(context: context)
    .environment(theme)
    .environment(Typography.default)
}
