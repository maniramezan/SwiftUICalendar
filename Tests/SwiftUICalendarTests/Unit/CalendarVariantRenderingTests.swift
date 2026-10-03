#if os(macOS)
import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// Mounts the calendar across the full variant matrix — every calendar system × scroll mode, every
/// grid sizing × scroll mode × width, and accessibility text sizes and appearances — and asserts
/// each renders non-blank without crashing. Complements the model matrix in
/// `CalendarVariantMatrixTests`, which verifies *what* resolves; this verifies the `body` builds.
@MainActor
@Suite("Calendar variant rendering", .serialized)
struct CalendarVariantRenderingTests {
    nonisolated static let modes: [CalendarConfiguration.ScrollMode] = [
        .none, .vertical, .horizontal,
    ]

    nonisolated static let yearCombos:
        [(
            CalendarConfiguration.YearSelection.Style, CalendarConfiguration.ScrollMode,
            Calendar.Identifier
        )] =
            [CalendarConfiguration.YearSelection.Style.wheel, .menu, .custom].flatMap { style in
                modes.flatMap { mode in
                    [Calendar.Identifier.gregorian, .persian].map { (style, mode, $0) }
                }
            }

    nonisolated static let appearanceCombos:
        [(DynamicTypeSize, ColorScheme, CalendarConfiguration.ScrollMode, Calendar.Identifier)] =
            [DynamicTypeSize.xSmall, .xxxLarge, .accessibility5].flatMap { size in
                [ColorScheme.light, .dark].flatMap { scheme in
                    modes.flatMap { mode in
                        [Calendar.Identifier.gregorian, .persian].map { (size, scheme, mode, $0) }
                    }
                }
            }

    private func mountNonBlank<V: View>(_ view: V, size: CGSize, _ label: String) {
        let hosted = hostView(view, size: size)
        defer { hosted.window.contentView = nil }
        waitForStableRender(hosted.hosting, timeout: 2)
        #expect(hosted.hosting.fittingSize.width >= 0, "\(label)")
        #expect(renderPNGData(hosted.hosting) != nil, "\(label): no frame")
    }

    @Test(
        "Every calendar system mounts in every scroll mode",
        arguments: CalendarVariantMatrixTests.identifiers, modes)
    func identifierByMode(
        identifier: Calendar.Identifier, mode: CalendarConfiguration.ScrollMode
    ) {
        let vm = CalendarViewModel.snapshot(identifier: identifier)
        mountNonBlank(
            CalendarView(model: vm, configuration: .init(scrollMode: mode)),
            size: CGSize(width: 390, height: 620), "\(identifier)/\(mode)")
    }

    @Test(
        "Every grid sizing mounts in every scroll mode at narrow and wide widths",
        arguments: CalendarVariantMatrixTests.sizingCombos.filter { $0.2 != 428 })
    func gridSizingByModeAndWidth(
        sizing: CalendarConfiguration.GridSizing, mode: CalendarConfiguration.ScrollMode,
        width: CGFloat
    ) {
        let vm = CalendarViewModel.snapshot(identifier: .gregorian)
        mountNonBlank(
            CalendarView(
                model: vm, configuration: .init(scrollMode: mode, gridSizing: sizing)),
            size: CGSize(width: width, height: 620), "\(sizing)/\(mode)/\(width)")
    }

    @Test(
        "Horizontal height modes mount for LTR and RTL systems",
        arguments: [CalendarConfiguration.HorizontalHeightMode.hugContent, .sixRows],
        [Calendar.Identifier.gregorian, .persian, .hebrew, .islamicUmmAlQura])
    func horizontalHeightModes(
        height: CalendarConfiguration.HorizontalHeightMode, identifier: Calendar.Identifier
    ) {
        let vm = CalendarViewModel.snapshot(identifier: identifier)
        mountNonBlank(
            CalendarView(
                model: vm,
                configuration: .init(scrollMode: .horizontal, horizontalHeightMode: height)),
            size: CGSize(width: 390, height: 620), "\(identifier)/\(height)")
    }

    @Test(
        "Year selection styles mount in every scroll mode and writing direction",
        arguments: yearCombos)
    func yearSelectionStyles(
        style: CalendarConfiguration.YearSelection.Style,
        mode: CalendarConfiguration.ScrollMode, identifier: Calendar.Identifier
    ) {
        let vm = CalendarViewModel.snapshot(identifier: identifier)
        mountNonBlank(
            CalendarView(
                model: vm,
                configuration: .init(
                    scrollMode: mode, yearSelection: .init(style: style))),
            size: CGSize(width: 390, height: 620), "\(style)/\(mode)/\(identifier)")
    }

    @Test(
        "Accessibility text sizes and appearances mount in every mode and direction",
        arguments: appearanceCombos)
    func accessibilityVariants(
        size: DynamicTypeSize, scheme: ColorScheme, mode: CalendarConfiguration.ScrollMode,
        identifier: Calendar.Identifier
    ) {
        let vm = CalendarViewModel.snapshot(identifier: identifier)
        mountNonBlank(
            CalendarView(model: vm, configuration: .init(scrollMode: mode))
                .environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, scheme),
            size: CGSize(width: 390, height: 700), "\(size)/\(scheme)/\(mode)/\(identifier)")
    }

    @Test(
        "Selection modes mount in every scroll mode",
        arguments: modes, [0, 1, 2])
    func selectionModes(mode: CalendarConfiguration.ScrollMode, kind: Int) throws {
        let gregorian = Calendar(identifier: .gregorian)
        let a = try #require(gregorian.date(from: DateComponents(year: 2025, month: 6, day: 10)))
        let b = try #require(gregorian.date(from: DateComponents(year: 2025, month: 6, day: 14)))
        let selection: CalendarViewModel.Selection =
            switch kind {
            case 0: .single(a)
            case 1: .multiple([a, b])
            default: .range(a, b)
            }
        let vm = CalendarViewModel.snapshot(identifier: .gregorian, selection: selection)
        mountNonBlank(
            CalendarView(model: vm, configuration: .init(scrollMode: mode)),
            size: CGSize(width: 390, height: 620), "\(mode)/selection\(kind)")
    }
}
#endif
