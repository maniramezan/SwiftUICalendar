#if os(macOS)
    import AppKit
    import DesignSystem
    import SwiftUI
    import Testing

    @testable import SwiftUICalendar

    /// `CalendarView` resolves its layout metrics from the design theme partway down its own body, so
    /// anything `CalendarView` reads for itself sees only the defaults. The header row height used to
    /// be read there, and so ignored a custom theme while every other metric followed it.
    @MainActor
    @Suite("Calendar theme resolution", .serialized)
    struct CalendarThemeResolutionTests {
        private static let size = CGSize(width: 600, height: 800)

        /// Top of the first week row, which sits below the header when there is one.
        private func firstRowTop(showsHeader: Bool, theme designTheme: any DesignSystem.Theme)
            throws
            -> CGFloat
        {
            let model = CalendarViewModel.snapshot(selection: .single(nil))
            let month = try #require(model.monthIdentifier())
            let frames = MeasuredDayFrames(month: month, calendar: model.engine.calendar)
            let theme = SwiftUICalendar.Theme()
            theme.day.setDayContent { context in
                MeasuringDayView(context: context, frames: frames)
            }
            let hosted = hostView(
                CalendarView(
                    model: model, theme: theme, configuration: .init(showsHeader: showsHeader)
                )
                .designTheme(designTheme),
                size: Self.size)
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            return try #require(frames.inMonth.values.map(\.minY).min())
        }

        /// Measures the header's contribution — first row with a header minus without — under each
        /// theme, so everything else that a theme changes cancels out.
        @Test("The header row follows a custom design theme")
        func headerRowFollowsTheme() throws {
            let defaultTheme = DesignSystem.DefaultTheme()
            let custom = DesignSystem.DefaultTheme(
                motion: DesignSystem.DefaultMotion(minimumHitTarget: 60))

            let defaultHeader =
                try firstRowTop(showsHeader: true, theme: defaultTheme)
                - firstRowTop(showsHeader: false, theme: defaultTheme)
            let customHeader =
                try firstRowTop(showsHeader: true, theme: custom)
                - firstRowTop(showsHeader: false, theme: custom)

            // 60 − 44: the custom theme's touch floor minus the default's.
            #expect(
                abs((customHeader - defaultHeader) - 16) < 0.5,
                "header grew by \(customHeader - defaultHeader) under a 60pt touch floor; expected 16"
            )
        }
    }
#endif
