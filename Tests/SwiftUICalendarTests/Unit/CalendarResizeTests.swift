#if os(macOS)
    import AppKit
    import SwiftUI
    import Testing

    @testable import SwiftUICalendar

    @MainActor
    @Suite("Calendar resizing", .serialized)
    struct CalendarResizeTests {
        @Test(
            "Resizing preserves day state and navigation",
            arguments: [
                CalendarConfiguration.ScrollMode.none, .vertical, .horizontal,
            ], [Calendar.Identifier.gregorian, .persian])
        func preservesIdentity(
            mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
        ) throws {
            let model = CalendarViewModel.snapshot(identifier: identifier, selection: .single(nil))
            let month = model.visibleMonth
            let identities = ResizeIdentities(date: model.currentDate)
            let theme = Theme()
            theme.day.setDayContent { context in
                ResizeDay(context: context, identities: identities)
            }
            let hosted = hostView(
                CalendarView(model: model, theme: theme, configuration: .init(scrollMode: mode)),
                size: CGSize(width: 600, height: 900))
            defer { hosted.window.contentView = nil }
            #expect(waitForStableRender(hosted.hosting))
            let original = identities.values
            #expect(!original.isEmpty)
            for width in [599.0, 800.0, 450.0, 600.0] {
                hosted.window.setContentSize(CGSize(width: width, height: 900))
                #expect(waitForStableRender(hosted.hosting))
                #expect(model.visibleMonth == month)
                for (date, identity) in original {
                    #expect(identities.values[date] == identity)
                }
            }
        }
    }

    @MainActor
    private final class ResizeIdentities {
        let date: Date
        var values: [Date: UUID] = [:]

        init(date: Date) { self.date = date }
    }

    private struct ResizeDay: CalendarDayView {
        let context: CalendarDayContext
        var identities: ResizeIdentities?
        @State private var identity = UUID()

        init(context: CalendarDayContext) {
            self.context = context
        }

        init(context: CalendarDayContext, identities: ResizeIdentities) {
            self.context = context
            self.identities = identities
        }

        var body: some View {
            Text(context.dayLabel)
                .onAppear {
                    if context.isInCurrentMonth,
                        let identities,
                        context.calendar.isDate(context.date, inSameDayAs: identities.date)
                    {
                        identities.values[context.date] = identity
                    }
                }
        }
    }
#endif
