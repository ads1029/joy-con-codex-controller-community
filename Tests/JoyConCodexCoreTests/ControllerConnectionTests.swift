import Foundation
import Testing
@testable import JoyConCodexCore

@Suite("Connection effects")
struct ControllerConnectionTests {
    @Test("Only arrivals trigger effects; rescans and battery updates do not")
    func arrivalEdges() {
        var tracker = ControllerConnectionTracker()
        let results = [tracker.update([]), tracker.update(["left"]), tracker.update(["left"]),
                       tracker.update(["left", "right"]), tracker.update(["left"]),
                       tracker.update([]), tracker.update(["left"])]
        #expect(results == [false, true, false, true, false, false, true])
    }

    @Test("Window restore consumes chords and retains neutral barrier")
    func suspendedInput() throws {
        var session = UnifiedControllerSession()
        let emitter = ConnectionRecorder()
        let token = try session.suspend(emitter: emitter)
        session.observeWhileSuspended(ControllerEvent(input: .leftTrigger, phase: .pressed, timestamp: .now))
        session.observeWhileSuspended(ControllerEvent(input: .buttonCapture, phase: .pressed, timestamp: .now))
        #expect(session.target == .codex)
        #expect(session.awaitingNeutral)
        #expect(!session.hasDeferredOutput)
        session.completeActivation(generation: token)
        let release = session.process(ControllerEvent(input: .buttonCapture, phase: .released, timestamp: .now),
                                      profile: .starter, testMode: false, emitter: emitter)
        #expect(release == .suppressed)
        #expect(session.awaitingNeutral)
        _ = session.process(ControllerEvent(input: .leftTrigger, phase: .released, timestamp: .now),
                            profile: .starter, testMode: false, emitter: emitter)
        #expect(!session.awaitingNeutral)
        #expect(emitter.events == 0)
    }
}

private final class ConnectionRecorder: ShortcutEmitting {
    var events = 0
    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws { events += 1 }
    func emit(_ scroll: ScrollCommand) throws { events += 1 }
}
