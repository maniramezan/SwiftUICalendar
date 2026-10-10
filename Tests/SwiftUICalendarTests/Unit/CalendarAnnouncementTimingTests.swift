#if os(macOS)
import Foundation
import SwiftUI
import Testing

@testable import SwiftUICalendar

/// Stands in for the settle delay: a sleep ends only when the test releases it, and a cancelled
/// sleep throws like `Task.sleep` does.
@MainActor
private final class ManualSleeper {
    private var pending: [Int: CheckedContinuation<Void, any Error>] = [:]
    private var nextID = 0
    private(set) var started = 0
    private(set) var cancelled = 0

    func sleep() async throws {
        let id = nextID
        nextID += 1
        try await withTaskCancellationHandler(
            operation: { () async throws -> Void in
                try await self.wait(id: id)
            },
            onCancel: {
                Task { @MainActor in self.cancel(id) }
            })
    }

    private func wait(id: Int) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            started += 1
            if Task.isCancelled {
                cancelled += 1
                continuation.resume(throwing: CancellationError())
            } else {
                pending[id] = continuation
            }
        }
    }

    private func cancel(_ id: Int) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        cancelled += 1
        continuation.resume(throwing: CancellationError())
    }

    /// Ends every sleep still waiting.
    func releaseAll() {
        let waiting = pending
        pending = [:]
        for continuation in waiting.values { continuation.resume() }
    }
}

/// Collects what the calendar would have spoken, in order, and owns the manual settle delay.
@MainActor
private final class AnnouncementRecorder {
    private(set) var messages: [AttributedString] = []
    let sleeper = ManualSleeper()

    var announcer: CalendarAnnouncer {
        CalendarAnnouncer(
            post: { [self] message in messages.append(message) },
            sleep: { [sleeper] _ in try await sleeper.sleep() })
    }

    /// Lets the run loop turn until `condition` holds. This waits for an event, never for a
    /// duration the assertions depend on, so load only makes it slower, not wrong.
    func until(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<500 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}

/// The announcement debounce, driven through a mounted calendar with VoiceOver reported as on.
///
/// Real speech needs a screen reader, so these assert what is posted and when: nothing for the month
/// shown at launch, nothing while the month is still changing, and one low-priority announcement
/// once navigation settles.
@MainActor
@Suite("Announcement timing", .serialized)
struct CalendarAnnouncementTimingTests {
    private func mount(
        voiceOver: Bool, recorder: AnnouncementRecorder
    ) -> (model: CalendarViewModel, dispose: () -> Void) {
        let model = CalendarViewModel.snapshot(selection: .single(nil))
        let size = CGSize(width: 393, height: 700)
        let hosted = hostView(
            CalendarView(model: model, configuration: .init(scrollMode: .none))
                .environment(\.calendarVoiceOverOverride, voiceOver)
                .environment(\.calendarAnnouncer, recorder.announcer),
            size: size)
        #expect(waitForStableRender(hosted.hosting))
        return (model, { hosted.window.contentView = nil })
    }

    @Test("The month shown at launch is neither announced nor waited on")
    func launchIsSilent() async throws {
        let recorder = AnnouncementRecorder()
        let mounted = mount(voiceOver: true, recorder: recorder)
        defer { mounted.dispose() }
        // Give any (wrong) launch announcement a chance to start before asserting it did not.
        try await Task.sleep(for: .milliseconds(200))
        recorder.sleeper.releaseAll()
        try await Task.sleep(for: .milliseconds(100))
        #expect(recorder.sleeper.started == 0)
        #expect(recorder.messages.isEmpty)
    }

    @Test("Rapid navigation announces only the month it settles on, at low priority")
    func rapidNavigationAnnouncesOnce() async throws {
        let recorder = AnnouncementRecorder()
        let mounted = mount(voiceOver: true, recorder: recorder)
        defer { mounted.dispose() }

        for expected in 1...3 {
            try mounted.model.updateMonthToNextMonth()
            #expect(await recorder.until { recorder.sleeper.started == expected })
        }
        // Three changes, three waits begun, the first two replaced before settling: nothing spoken.
        #expect(await recorder.until { recorder.sleeper.cancelled == 2 })
        #expect(recorder.messages.isEmpty)

        recorder.sleeper.releaseAll()
        #expect(await recorder.until { !recorder.messages.isEmpty })
        // Let any stray extra announcement land before counting.
        try await Task.sleep(for: .milliseconds(100))
        #expect(recorder.messages.count == 1)
        let settled = mounted.model.visibleMonth
        let message = try #require(recorder.messages.first)
        let text = String(message.characters)
        #expect(text.contains(mounted.model.monthSymbol(for: settled)))
        #expect(text.contains(mounted.model.yearTitle(settled.year)))
        #expect(message.accessibilitySpeechAnnouncementPriority == .low)
    }

    @Test("Without VoiceOver nothing is announced")
    func silentWithoutVoiceOver() async throws {
        let recorder = AnnouncementRecorder()
        let mounted = mount(voiceOver: false, recorder: recorder)
        defer { mounted.dispose() }
        try mounted.model.updateMonthToNextMonth()
        try await Task.sleep(for: .milliseconds(200))
        recorder.sleeper.releaseAll()
        try await Task.sleep(for: .milliseconds(100))
        #expect(recorder.sleeper.started == 0)
        #expect(recorder.messages.isEmpty)
    }
}
#endif
