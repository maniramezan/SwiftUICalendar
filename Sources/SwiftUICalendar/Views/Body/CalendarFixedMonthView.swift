import OSLog
import SwiftCommons
import SwiftUI

struct CalendarFixedMonthView: View {
    let viewModel: CalendarViewModel
    let layoutWidth: CGFloat?
    let keyboard: CalendarKeyboardCursor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fade: CalendarMonthFade
    private let logger = Logger.swiftUICalendar(for: Self.self)

    init(viewModel: CalendarViewModel, layoutWidth: CGFloat?, keyboard: CalendarKeyboardCursor) {
        self.viewModel = viewModel
        self.layoutWidth = layoutWidth
        self.keyboard = keyboard
        _fade = State(initialValue: CalendarMonthFade(month: viewModel.visibleMonth))
    }

    var body: some View {
        VStack(spacing: 0) {
            CalendarBodyView(
                monthIdentifier: fade.displayedMonth,
                layoutWidth: layoutWidth, keyboard: keyboard,
                onOverflowSelection: { date in
                    guard viewModel.engine.containsDay(date) else { return }
                    transition(to: viewModel.engine.month(containing: date), selecting: date)
                },
                showsSelection: fade.phase != .fadingIn
            )
            .id(fade.displayedMonth)
            .opacity(fade.opacity)
            .allowsHitTesting(fade.phase == .idle)
        }
        .onChange(of: viewModel.visibleMonth) { _, month in
            transition(to: month)
        }
        .onDisappear {
            fade.cancel(showing: viewModel.visibleMonth)
        }
    }

    private func transition(to month: MonthIdentifier, selecting date: Date? = nil) {
        guard let token = fade.begin(to: month, selecting: date) else { return }
        withAnimation(
            reduceMotion ? nil : .easeOut(duration: 0.12), completionCriteria: .removed
        ) {
            fade.opacity = 0
        } completion: {
            do {
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                let shouldFadeIn = try withTransaction(transaction) {
                    try fade.finishFadeOut(token, model: viewModel)
                }
                guard shouldFadeIn else { return }
                withAnimation(
                    reduceMotion ? nil : .easeIn(duration: 0.16), completionCriteria: .removed
                ) {
                    fade.opacity = 1
                } completion: {
                    fade.finishFadeIn(token, model: viewModel)
                }
            } catch {
                logger.error(
                    "Failed to navigate during month fade", error: error,
                    context: "month \(month.month), year \(month.year)")
                fade.cancel(showing: viewModel.visibleMonth)
            }
        }
    }
}
