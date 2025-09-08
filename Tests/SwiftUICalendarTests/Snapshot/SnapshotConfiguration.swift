import Foundation
import SnapshotTesting
import SwiftUI

@testable import SwiftUICalendar

// MARK: - Global record mode
// ⚠️ Set to .all to record baseline snapshots, then revert to .missing for CI
let globalRecordMode: SnapshotTestingConfiguration.Record = .missing

// MARK: - CalendarViewModel snapshot factory

extension CalendarViewModel {
    /// Creates a view model pinned to June 1, 2025 (Gregorian) for deterministic snapshots.
    static func snapshot(
        identifier: Calendar.Identifier = .gregorian,
        selection: Selection = .single(nil)
    ) -> CalendarViewModel {
        let vm = CalendarViewModel(calendarIdentifier: identifier, selection: selection)
        vm.currentDate = Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 2025, month: 6, day: 1))!
        return vm
    }
}

// MARK: - Platform-agnostic snapshot assertion

/// Asserts an image snapshot of a SwiftUI view at the given width.
/// On iOS/tvOS uses UIHostingController; on macOS uses NSHostingView.
/// Call site's `#filePath`, `#function`, and `#line` are forwarded automatically.
@MainActor
func assertCalendarSnapshot<V: View>(
    of view: V,
    width: CGFloat = 390,
    height: CGFloat? = nil,
    named name: String? = nil,
    file: StaticString = #filePath,
    testName: String = #function,
    line: UInt = #line
) {
    withSnapshotTesting(record: globalRecordMode) {
        #if os(iOS) || os(tvOS)
        let layout: SwiftUISnapshotLayout = {
            if let h = height {
                return .fixed(width: width, height: h)
            }
            return .fixed(width: width, height: 460)
        }()
        assertSnapshot(
            of: view,
            as: .image(layout: layout),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
        #elseif os(macOS)
        let targetHeight = height ?? 460
        let size = CGSize(width: width, height: targetHeight)
        let hosting = NSHostingView(rootView: view.frame(width: width))
        hosting.frame = CGRect(origin: .zero, size: size)
        assertSnapshot(
            of: hosting,
            as: .image(size: size),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
        #endif
    }
}
