import Foundation
import SnapshotTesting

@testable import SwiftUICalendar

// MARK: - Global record mode
// Structural snapshots are plain text and render identically on every machine, so recording is a
// normal local step: set `SNAPSHOT_RECORD_MODE=all` (or flip this to `.all`) to regenerate the
// `.txt` baselines, then run once more to verify.
let globalRecordMode: SnapshotTestingConfiguration.Record = {
  if ProcessInfo.processInfo.environment["SNAPSHOT_RECORD_MODE"] == "all" {
    return .all
  }
  return .missing
}()

// Explicit opt-out is represented as skipped suites, never successful no-op assertions.
let snapshotsEnabled = ProcessInfo.processInfo.environment["SNAPSHOT_ASSERTIONS"] != "false"

// MARK: - CalendarViewModel snapshot factory

extension CalendarViewModel {
  /// Creates a view model pinned to June 1, 2025 (Gregorian) for deterministic snapshots.
  static func snapshot(
    identifier: Calendar.Identifier = .gregorian,
    selection: Selection = .single(nil)
  ) -> CalendarViewModel {
    let vm = CalendarViewModel(calendarIdentifier: identifier, selection: selection)
    if let pinned = Calendar(identifier: .gregorian)
      .date(from: DateComponents(year: 2025, month: 6, day: 1))
    {
      vm.currentDate = pinned
    }
    return vm
  }
}
