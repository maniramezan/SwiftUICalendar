import SwiftUI

struct CalendarBodyHorizontalView: View {
  private static let headerHeightRatio: CGFloat = 0.45
  private static let minHeaderHeight: CGFloat = 24
  private static let heightCeilingPadding: CGFloat = 2
  private static let swipeThresholdRatio: CGFloat = 0.25
  private static let minimumSwipeThreshold: CGFloat = 56
  private static let pagingAnimation = Animation.interactiveSpring(
    response: 0.32,
    dampingFraction: 0.88,
    blendDuration: 0.12
  )
  private static let snapBackAnimation = Animation.interactiveSpring(
    response: 0.24,
    dampingFraction: 0.9,
    blendDuration: 0.08
  )

  @Environment(Theme.self) var theme
  @Environment(Typography.self) var typography
  @Environment(\.calendarMetrics) private var metrics
  @Environment(\.layoutDirection) private var layoutDirection
  let viewModel: CalendarViewModel

  @State private var previousViewModel: CalendarViewModel
  @State private var currentViewModel: CalendarViewModel
  @State private var nextViewModel: CalendarViewModel
  @State private var offset: CGFloat = 0
  @State private var dragOffset: CGFloat = 0
  @State private var containerWidth: CGFloat = 0
  @State private var measuredHeight: CGFloat = 0
  @State private var isNavigating = false

  private var layoutWidth: CGFloat {
    // Cap the carousel width so cells stop growing on wide windows; the ZStack's
    // `.frame(maxWidth: .infinity)` then centers the capped months in the container.
    min(max(containerWidth, metrics.minCalendarWidth), metrics.maxCalendarWidth)
  }

  private var cellSize: CGFloat {
    let totalInteritemSpacing = metrics.itemSpacing * 6
    let widthForCells = max(0, layoutWidth - totalInteritemSpacing)
    let columnWidth = widthForCells / 7
    return min(metrics.maxCellSize, max(metrics.minCellSize, columnWidth))
  }

  private var weekdayHeaderHeight: CGFloat {
    max(Self.headerHeightRatio * cellSize, Self.minHeaderHeight)
  }

  private var columns: [GridItem] {
    Array(
      repeating: GridItem(
        .flexible(minimum: metrics.minCellSize), spacing: metrics.itemSpacing, alignment: .center),
      count: 7
    )
  }

  private var calendarHeight: CGFloat {
    height(forRowCount: rowCountForHeight)
  }

  /// `1` for LTR, `-1` for RTL.
  /// Applied manually because the ZStack is forced to `.leftToRight`
  /// to prevent SwiftUI's automatic coordinate flipping.
  private var layoutDirectionMultiplier: CGFloat {
    layoutDirection == .rightToLeft ? -1 : 1
  }

  private var previousMonthBaseOffset: CGFloat {
    -layoutWidth * layoutDirectionMultiplier
  }

  private var nextMonthBaseOffset: CGFloat {
    layoutWidth * layoutDirectionMultiplier
  }

  init(viewModel: CalendarViewModel) {
    self.viewModel = viewModel
    let vm = viewModel
    self._currentViewModel = State(initialValue: vm)
    self._previousViewModel = State(initialValue: (try? vm.copy(addMonths: -1)) ?? vm)
    self._nextViewModel = State(initialValue: (try? vm.copy(addMonths: 1)) ?? vm)
  }

  var body: some View {
    VStack(spacing: metrics.rowSpacing) {
      // Static weekday header — does not scroll with the carousel
      LazyVGrid(columns: columns, alignment: .center, spacing: 0) {
        ForEach(Array(viewModel.headerTitles.enumerated()), id: \.offset) { _, day in
          Text(day)
            .font(typography.weekdayHeaderFont)
            .lineLimit(1)
            .minimumScaleFactor(typography.minScaleFactor ?? 1.0)
            .frame(height: weekdayHeaderHeight)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(width: layoutWidth)
      .accessibilityHidden(true)

      // Day-grid carousel.
      // Swipe semantics are fixed across locales:
      // swipe left to move forward (next month),
      // swipe right to move backward (previous month).
      //
      // Layout differs by direction:
      // LTR: previous | current | next
      // RTL: next | current | previous
      ZStack(alignment: .topLeading) {
        // Previous month — parked to the left.
        CalendarBodyView(showWeekdayHeader: false, hideOverflowDays: true)
          .environment(previousViewModel)
          .environment(theme)
          .environment(typography)
          .environment(\.layoutDirection, layoutDirection)
          .frame(width: layoutWidth, alignment: .top)
          .background(heightReporter(for: .previous))
          .clipped()
          .offset(x: previousMonthBaseOffset + offset + dragOffset)

        // Current month (centered by default)
        CalendarBodyView(showWeekdayHeader: false, hideOverflowDays: true)
          .environment(currentViewModel)
          .environment(theme)
          .environment(typography)
          .environment(\.layoutDirection, layoutDirection)
          .frame(width: layoutWidth, alignment: .top)
          .background(heightReporter(for: .current))
          .clipped()
          .offset(x: offset + dragOffset)

        // Next month — parked to the right.
        CalendarBodyView(showWeekdayHeader: false, hideOverflowDays: true)
          .environment(nextViewModel)
          .environment(theme)
          .environment(typography)
          .environment(\.layoutDirection, layoutDirection)
          .frame(width: layoutWidth, alignment: .top)
          .background(heightReporter(for: .next))
          .clipped()
          .offset(x: nextMonthBaseOffset + offset + dragOffset)
      }
      .environment(\.layoutDirection, .leftToRight)
      .frame(minHeight: max(calendarHeight, measuredHeight), alignment: .topLeading)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .onChange(of: viewModel.currentDate) { _, _ in
        syncFromBinding()
      }
      .onChange(of: viewModel.selection) { _, _ in
        syncFromBinding()
      }
      .onChange(of: viewModel.calendarSignature) { _, _ in
        syncFromBinding()
      }
      .onPreferenceChange(HorizontalMonthHeightPreferenceKey.self) { heights in
        measuredHeight = heights.values.max() ?? 0
      }
      .gesture(
        DragGesture()
          .onChanged { value in
            guard !isNavigating else {
              return
            }

            dragOffset = HorizontalMonthSwipeResolver.clampedTranslation(
              value.translation.width,
              limit: layoutWidth
            )
          }
          .onEnded { value in
            guard !isNavigating else {
              return
            }

            let threshold = max(
              layoutWidth * Self.swipeThresholdRatio,
              Self.minimumSwipeThreshold
            )
            let resolvedTranslation = HorizontalMonthSwipeResolver.resolvedTranslation(
              translation: value.translation.width * layoutDirectionMultiplier,
              predictedEndTranslation: value.predictedEndTranslation.width
                * layoutDirectionMultiplier,
              limit: layoutWidth
            )
            let monthDelta = HorizontalMonthSwipeResolver.monthDelta(
              for: resolvedTranslation,
              threshold: threshold
            )

            if monthDelta == 1 {
              goToNext(width: layoutWidth)
            } else if monthDelta == -1 {
              goToPrevious(width: layoutWidth)
            } else {
              withAnimation(Self.snapBackAnimation) {
                dragOffset = 0
              }
            }
          }
      )
      .background(
        GeometryReader { geometry in
          Color.clear
            .onAppear { containerWidth = geometry.size.width }
            .onChange(of: geometry.size.width) { _, newWidth in
              containerWidth = newWidth
            }
        }
      )
    }
  }

  private func heightReporter(for position: HorizontalMonthPosition) -> some View {
    GeometryReader { geometry in
      Color.clear
        .preference(
          key: HorizontalMonthHeightPreferenceKey.self,
          value: [position: geometry.size.height]
        )
    }
  }

  private func syncFromBinding() {
    guard !isNavigating else { return }
    currentViewModel = viewModel
    previousViewModel = (try? viewModel.copy(addMonths: -1)) ?? viewModel
    nextViewModel = (try? viewModel.copy(addMonths: 1)) ?? viewModel
  }

  private var rowCountForHeight: Int {
    switch theme.horizontalHeightMode {
    case .hugContent:
      let current = currentViewModel.rowCount(
        month: currentViewModel.currentMonth, year: currentViewModel.currentYear)
      let previous = previousViewModel.rowCount(
        month: previousViewModel.currentMonth, year: previousViewModel.currentYear)
      let next = nextViewModel.rowCount(
        month: nextViewModel.currentMonth, year: nextViewModel.currentYear)
      return max(current, previous, next)
    case .sixRows:
      return 6
    }
  }

  private func height(forRowCount rowCount: Int) -> CGFloat {
    let totalInteritemSpacing = metrics.itemSpacing * 6
    let widthForCells = max(0, layoutWidth - totalInteritemSpacing)
    let columnWidth = widthForCells / 7
    let cs = min(metrics.maxCellSize, max(metrics.minCellSize, columnWidth))
    // Grid only: (rowCount - 1) spacings between rows (header is static above carousel)
    let totalRowSpacing = metrics.rowSpacing * CGFloat(rowCount - 1)
    let h = (CGFloat(rowCount) * cs) + totalRowSpacing
    return ceil(h) + Self.heightCeilingPadding
  }

  /// Swipe LEFT: next month slides in from the right.
  private func goToNext(width: CGFloat) {
    guard !isNavigating else {
      return
    }

    isNavigating = true
    let savedCurrent = currentViewModel

    withAnimation(Self.pagingAnimation, completionCriteria: .logicallyComplete) {
      // Move until the parked next month reaches center.
      offset += -width * layoutDirectionMultiplier
      dragOffset = 0
    } completion: {
      finishNavigation(monthDelta: 1, savedCurrent: savedCurrent)
    }
  }

  /// Swipe RIGHT: previous month slides in from the left.
  private func goToPrevious(width: CGFloat) {
    guard !isNavigating else {
      return
    }

    isNavigating = true
    let savedCurrent = currentViewModel

    withAnimation(Self.pagingAnimation, completionCriteria: .logicallyComplete) {
      // Move until the parked previous month reaches center.
      offset += width * layoutDirectionMultiplier
      dragOffset = 0
    } completion: {
      finishNavigation(monthDelta: -1, savedCurrent: savedCurrent)
    }
  }

  private func finishNavigation(monthDelta: Int, savedCurrent: CalendarViewModel) {
    guard monthDelta == 1 || monthDelta == -1 else {
      withTransaction(Transaction(animation: nil)) {
        offset = 0
        dragOffset = 0
      }
      isNavigating = false
      syncFromBinding()
      return
    }

    if (try? viewModel.updateMonth(byAdding: monthDelta)) == nil {
      withTransaction(Transaction(animation: nil)) {
        offset = 0
        dragOffset = 0
      }
      isNavigating = false
      syncFromBinding()
      return
    }

    if monthDelta == 1 {
      previousViewModel = savedCurrent
      currentViewModel = nextViewModel
      nextViewModel = (try? viewModel.copy(addMonths: 1)) ?? viewModel
    } else {
      nextViewModel = savedCurrent
      currentViewModel = previousViewModel
      previousViewModel = (try? viewModel.copy(addMonths: -1)) ?? viewModel
    }

    withTransaction(Transaction(animation: nil)) {
      offset = 0
      dragOffset = 0
    }

    isNavigating = false
    syncFromBinding()
  }
}

private enum HorizontalMonthPosition: Hashable {
  case previous
  case current
  case next
}

enum HorizontalMonthSwipeResolver {
  private static let momentumWeight: CGFloat = 0.65

  static func clampedTranslation(_ translation: CGFloat, limit: CGFloat) -> CGFloat {
    let clampedLimit = max(limit, 0)
    return min(max(translation, -clampedLimit), clampedLimit)
  }

  static func resolvedTranslation(
    translation: CGFloat,
    predictedEndTranslation: CGFloat,
    limit: CGFloat
  ) -> CGFloat {
    let weighted = (translation * (1 - momentumWeight)) + (predictedEndTranslation * momentumWeight)
    return clampedTranslation(weighted, limit: limit)
  }

  /// Returns the month delta for a swipe gesture.
  ///
  /// - Returns: `+1` (go to next), `-1` (go to previous),
  ///   `nil` if the translation is within threshold.
  ///
  /// This resolver intentionally keeps the same swipe mapping
  /// for both LTR and RTL:
  /// swipe left (negative) → next,
  /// swipe right (positive) → previous.
  static func monthDelta(
    for translation: CGFloat,
    threshold: CGFloat
  ) -> Int? {
    if translation < -threshold { return 1 }
    if translation > threshold { return -1 }
    return nil
  }
}

private struct HorizontalMonthHeightPreferenceKey: PreferenceKey {
  static let defaultValue: [HorizontalMonthPosition: CGFloat] = [:]

  static func reduce(
    value: inout [HorizontalMonthPosition: CGFloat],
    nextValue: () -> [HorizontalMonthPosition: CGFloat]
  ) {
    value.merge(nextValue(), uniquingKeysWith: { max($0, $1) })
  }
}

#Preview {
  @Previewable @State var vm = CalendarViewModel.test(identifier: .persian)
  return CalendarBodyHorizontalView(viewModel: vm)
    .environment(Theme.default)
    .environment(Typography.default)
}
