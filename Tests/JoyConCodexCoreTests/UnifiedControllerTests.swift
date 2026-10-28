import Foundation
import Testing
@testable import JoyConCodexCore

@Suite("Unified controller transitions")
struct UnifiedControllerTests {
    private let origin = Date(timeIntervalSince1970: 10_000)
    private func event(_ input: ControllerInput, _ phase: InputPhase, _ offset: Double = 0) -> ControllerEvent {
        ControllerEvent(input: input, phase: phase, timestamp: origin.addingTimeInterval(offset))
    }
    private var profile: MappingProfile {
        var profile = MappingProfile.starter
        profile.update(InputMapping(input: .buttonCapture,
            primaryAction: .tap(Shortcut(keyCode: 124, displayLabel: "Right Arrow", modifiers: [.control, .option])),
            doubleTapAction: .tap(Shortcut(keyCode: 123, displayLabel: "Left Arrow", modifiers: [.control, .option]))))
        profile.update(InputMapping(input: .leftStickUp, primaryAction: .scrollUp))
        return profile
    }

    private func zlTaps(_ count: Int, starting offset: Double = 0, step: Double = 0.15,
        hold: Double = 0.05, input: ControllerInput = .leftTrigger) -> [ControllerEvent] {
        (0..<count).flatMap { i in
            [event(input, .pressed, offset + Double(i) * step),
             event(input, .released, offset + Double(i) * step + hold)]
        }
    }

    private func tripleSwitch(_ session: inout UnifiedControllerSession, emitter: UnifiedRecorder,
        starting offset: Double = 0, testMode: Bool = false) -> UnifiedSessionResult {
        var result = UnifiedSessionResult.suppressed
        for e in zlTaps(3, starting: offset) {
            result = session.process(e, profile: profile, testMode: testMode, emitter: emitter)
        }
        return result
    }

    @Test("Three complete ZL taps switch once, only on the third release")
    func chordPriority() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        let events = zlTaps(3)
        for e in events.dropLast() {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
            #expect(session.target == .codex)
        }
        let result = session.process(events.last!, profile: profile, testMode: false, emitter: emitter)
        #expect(result == .targetChanged(.claudeCode, generation: 1))
        #expect(emitter.keys.isEmpty)
        #expect(!session.isReady)
        #expect(!session.awaitingNeutral)
        _ = session.process(events.last!, profile: profile, testMode: false, emitter: emitter)
        #expect(session.generation == 1)
        #expect(session.advance(to: origin.addingTimeInterval(10), testMode: false, emitter: emitter).isEmpty)
    }

    @Test("Single/double ZL, long holds, slow gaps and overlong sequences do not switch")
    func invalidZLSequences() {
        let cases = [zlTaps(1), zlTaps(2), zlTaps(3, step: 0.5, hold: 0.4),
            zlTaps(3, step: 0.5), zlTaps(3, step: 0.5, hold: 0.2)]
        for events in cases {
            var session = UnifiedControllerSession()
            let emitter = UnifiedRecorder()
            for e in events { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
            #expect(session.target == .codex)
            #expect(!session.isFunctionLayerActive)
        }
    }

    @Test("ZL function combinations are immediate and cancel triple-tap history")
    func functionCombinationCancelsSwitch() {
        var session = UnifiedControllerSession(target: .claudeCode)
        let emitter = UnifiedRecorder()
        for e in zlTaps(2) + [event(.leftTrigger, .pressed, 0.3)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        #expect(session.isFunctionLayerActive)
        _ = session.process(event(.leftStickRight, .pressed, 0.32), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.desktopActions == [.focusPrompt(.right)])
        for input in [ControllerInput.leftTrigger, .leftStickRight] {
            _ = session.process(event(input, .released, 0.35), profile: profile, testMode: false, emitter: emitter)
        }
        for e in zlTaps(2, starting: 0.4) {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        #expect(session.target == .claudeCode)
    }

    @Test("A normal Fn shortcut cancels prior ZL taps without delaying its output")
    func normalFnCancelsTaps() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in zlTaps(2) + [event(.leftTrigger, .pressed, 0.3),
            event(.dpadLeft, .pressed, 0.31), event(.dpadLeft, .released, 0.32),
            event(.leftTrigger, .released, 0.33)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        #expect(emitter.keys.map(\.0) == [profile.mapping(for: .dpadLeft)!.functionAction!.shortcut!])
        for e in zlTaps(2, starting: 0.4) { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
        #expect(session.target == .codex)
    }

    @Test("ZL taps while another control is held cannot switch or interrupt recording")
    func heldControlBlocksTriple() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: false, emitter: emitter)
        for e in zlTaps(3, starting: 0.1) { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
        #expect(session.target == .codex && emitter.held)
        _ = session.process(event(.leftShoulder, .released, 0.7), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp])
    }

    @Test("Old ZL+Capture is disabled with either release order; ordinary Capture still works")
    func formerChordDisabled() {
        for order in [[ControllerInput.leftTrigger, .buttonCapture], [.buttonCapture, .leftTrigger]] {
            var session = UnifiedControllerSession()
            let emitter = UnifiedRecorder()
            for e in [event(.leftTrigger, .pressed), event(.buttonCapture, .pressed, 0.02)] {
                _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
            }
            for (i, input) in order.enumerated() {
                _ = session.process(event(input, .released, 0.04 + Double(i) * 0.01), profile: profile, testMode: false, emitter: emitter)
            }
            _ = session.advance(to: origin.addingTimeInterval(1), testMode: false, emitter: emitter)
            #expect(session.target == .codex)
            #expect(emitter.keys.isEmpty)
            for e in [event(.buttonCapture, .pressed, 2), event(.buttonCapture, .released, 2.02)] {
                _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
            }
            _ = session.advance(to: origin.addingTimeInterval(3), testMode: false, emitter: emitter)
            #expect(emitter.keys.count == 1)
        }
    }

    @Test("Duplicate ZL edges cannot synthesize extra taps")
    func duplicateZLEdges() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in zlTaps(2) {
            for _ in 0..<3 { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
        }
        #expect(session.target == .codex)
        for e in zlTaps(1, starting: 0.3) {
            for _ in 0..<3 { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
        }
        #expect(session.target == .claudeCode)
        #expect(session.generation == 1)
    }

    @Test("Switch cancels pending Capture before its deadline and round trips without input output")
    func tripleCancelsPendingCapture() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.buttonCapture, .pressed), event(.buttonCapture, .released, 0.01)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        for e in zlTaps(3, starting: 0.02, step: 0.05, hold: 0.02) {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        #expect(!session.hasDeferredOutput)
        session.completeActivation(generation: session.generation)
        _ = session.advance(to: origin.addingTimeInterval(1), testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        _ = tripleSwitch(&session, emitter: emitter, starting: 2)
        #expect(session.target == .codex)
        #expect(session.generation == 2)
    }

    @Test("Suspension, desktop restoration and disconnect discard partial ZL sequences")
    func suspendedZLSequences() throws {
        for mode in 0..<3 {
            var session = UnifiedControllerSession()
            let emitter = UnifiedRecorder()
            for e in zlTaps(2) { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
            if mode == 0 { try session.outputModeChanged(emitter: emitter) }
            if mode == 1 {
                session.observeWhileSuspended(event(.leftTrigger, .pressed, 0.25))
                session.observeWhileSuspended(event(.leftTrigger, .released, 0.26))
            }
            if mode == 2 {
                try session.disconnected(emitter: emitter)
                _ = session.process(event(.leftTrigger, .released, 0.26), profile: profile, testMode: false, emitter: emitter)
                session.completeActivation(generation: session.generation)
            }
            for e in zlTaps(1, starting: 0.3) { _ = session.process(e, profile: profile, testMode: false, emitter: emitter) }
            #expect(session.target == .codex)
        }
    }

    @Test("Plain Capture single is deferred then emitted exactly once")
    func captureSingle() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.buttonCapture, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.buttonCapture, .released, 0.05), profile: profile, testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(0.3), testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        _ = session.advance(to: origin.addingTimeInterval(0.34), testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(1), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [profile.mapping(for: .buttonCapture)!.primaryAction!.shortcut!])
    }

    @Test("Plain Capture double cancels its single and emits only the original double")
    func captureDouble() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.buttonCapture, .pressed), event(.buttonCapture, .released, 0.04),
            event(.buttonCapture, .pressed, 0.1), event(.buttonCapture, .released, 0.14)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(1), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [profile.mapping(for: .buttonCapture)!.doubleTapAction!.shortcut!])
        #expect(session.target == .codex)
    }

    @Test("A held second Capture cancels the single even across the old deadline")
    func heldSecondCapture() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.buttonCapture, .pressed), event(.buttonCapture, .released, 0.04),
            event(.buttonCapture, .pressed, 0.1), event(.buttonCapture, .pressed, 0.2)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(1), testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        for _ in 0..<2 {
            _ = session.process(event(.buttonCapture, .released, 1.1), profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(2), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [profile.mapping(for: .buttonCapture)!.doubleTapAction!.shortcut!])
        #expect(!session.hasDeferredOutput)
    }

    @Test("Raw HID ZL triple taps switch while L and portrait Capture retain their routes")
    func physicalMappingRoutes() throws {
        let l = try #require(LeftJoyConHIDMapping.input(forButtonUsage: 15))
        let zl = try #require(LeftJoyConHIDMapping.input(forButtonUsage: 16))
        let capture = LeftJoyConPortraitMapping.input(for: .buttonHome)
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(l, .pressed), event(l, .released, 0.1)] + zlTaps(3, starting: 0.2, input: zl) {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        #expect(session.target == .claudeCode)
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp])
        #expect(!emitter.held)
        session.completeActivation(generation: session.generation)
        for e in [event(capture, .pressed, 2), event(capture, .released, 2.02)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(3), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp, .tap])
        #expect(emitter.keys.last?.0 == profile.mapping(for: .buttonCapture)?.primaryAction?.shortcut)
    }

    @Test("A switch cancels pending Capture, active repeat and held dictation before changing target")
    func switchClearsAllDeferredOutput() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.buttonCapture, .pressed), event(.buttonCapture, .released, 0.01),
            event(.leftStickUp, .pressed, 0.02), event(.leftShoulder, .pressed, 0.03),
            event(.leftTrigger, .pressed, 0.04)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        #expect(session.hasDeferredOutput)
        #expect(emitter.scrolls == [.up])
        #expect(emitter.keys.map(\.1) == [.keyDown])
        let changed = session.selectTarget(.claudeCode, testMode: false, emitter: emitter)
        #expect(changed == .targetChanged(.claudeCode, generation: 1))
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp])
        #expect(!session.hasDeferredOutput)
        session.completeActivation(generation: 1)
        for input in [ControllerInput.leftShoulder, .leftStickUp, .leftTrigger, .buttonCapture] {
            _ = session.process(event(input, .released, 0.1), profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(100), testMode: false, emitter: emitter)
        #expect(emitter.keys.count == 2)
        #expect(emitter.scrolls == [.up])
        #expect(!session.awaitingNeutral)
    }

    @Test("Target activation cannot bypass the all-controls-neutral barrier")
    func neutralBarrier() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftTrigger, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.buttonCapture, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.selectTarget(.claudeCode, testMode: false, emitter: emitter)
        session.completeActivation(generation: 1)
        _ = session.process(event(.dpadRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftTrigger, .released), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.buttonCapture, .released), profile: profile, testMode: false, emitter: emitter)
        #expect(session.awaitingNeutral)
        _ = session.process(event(.dpadRight, .released), profile: profile, testMode: false, emitter: emitter)
        #expect(!session.awaitingNeutral)
        #expect(emitter.keys.isEmpty)
        _ = session.process(event(.dpadRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.count == 1)
        #expect(emitter.keys[0].0.keyCode == 36)
    }

    @Test("Capture-before-ZL is an ordinary tap, never a retroactive switch")
    func chordOrder() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.buttonCapture, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftTrigger, .pressed, 0.01), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.buttonCapture, .released, 0.02), profile: profile, testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(1), testMode: false, emitter: emitter)
        #expect(session.target == .codex)
        #expect(emitter.keys.count == 1)
    }

    @Test("Test mode previews switches and Capture without output")
    func testMode() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.buttonCapture, .pressed), event(.buttonCapture, .released, 0.02)] {
            _ = session.process(e, profile: profile, testMode: true, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(1), testMode: true, emitter: emitter)
        _ = tripleSwitch(&session, emitter: emitter, starting: 2, testMode: true)
        #expect(session.target == .claudeCode)
        #expect(session.isReady)
        #expect(emitter.keys.isEmpty && emitter.scrolls.isEmpty)
    }

    @Test("Leaving Test Mode accepts a fresh L hold without a focus or stick event")
    func liveModeManualFocus() throws {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: true, emitter: emitter)
        _ = session.process(event(.leftShoulder, .released, 0.02), profile: profile, testMode: true, emitter: emitter)
        try session.outputModeChanged(emitter: emitter)
        #expect(session.isReady && !session.awaitingNeutral)
        _ = session.process(event(.leftShoulder, .pressed, 1), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftShoulder, .released, 1.1), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp])
        #expect(emitter.keys.map(\.0) == Array(repeating: profile.mapping(for: .leftShoulder)!.primaryAction!.shortcut!, count: 2))
    }

    @Test("Mode changes still require a held preview control to return to neutral")
    func liveModeHeldBarrier() throws {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: true, emitter: emitter)
        try session.outputModeChanged(emitter: emitter)
        #expect(session.isReady && session.awaitingNeutral)
        _ = session.process(event(.leftShoulder, .pressed, 1), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftShoulder, .released, 1.1), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        _ = session.process(event(.leftShoulder, .pressed, 2), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.1) == [.keyDown])
        try session.outputModeChanged(emitter: emitter)
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp])
        #expect(session.awaitingNeutral)
    }

    @Test("Failed hold cleanup cannot re-arm output on a mode change")
    func failedModeChangeCleanup() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: false, emitter: emitter)
        emitter.failRelease = true
        #expect(throws: (any Error).self) { try session.outputModeChanged(emitter: emitter) }
        #expect(!session.isReady && emitter.held)
        _ = session.process(event(.leftShoulder, .released, 1), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftShoulder, .pressed, 2), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.1) == [.keyDown])
    }

    @Test("SL/SR remain disabled even if an imported profile binds them")
    func railsDisabled() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for input in [ControllerInput.buttonSL, .buttonSR] {
            _ = session.process(event(input, .pressed), profile: .starter, testMode: false, emitter: emitter)
            _ = session.process(event(input, .released), profile: .starter, testMode: false, emitter: emitter)
        }
        #expect(emitter.keys.isEmpty)
        #expect(session.heldInputs.isEmpty)
    }

    @Test("Failed release leaves target unchanged and recovery is retried before a later switch")
    func failedRelease() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: false, emitter: emitter)
        emitter.failRelease = true
        let failed = session.selectTarget(.claudeCode, testMode: false, emitter: emitter)
        if case .failed = failed {} else { Issue.record("A failed release must reject the transition") }
        #expect(session.target == .codex && !session.isReady)
        #expect(emitter.recoveries == 1)
        emitter.failRelease = false
        _ = session.selectTarget(.claudeCode, testMode: false, emitter: emitter)
        #expect(emitter.recoveries == 2)
        #expect(!emitter.held)
        #expect(session.target == .claudeCode)
    }

    @Test("Codex foreground activation arms L without looking for a Claude AX prompt")
    func codexActivationWithoutPrompt() throws {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        let token = try session.suspend(emitter: emitter)
        var validated = false
        var lookedForPrompt = false
        try DesktopActivationPolicy.complete(for: .codex, validateDestination: {
            validated = true
        }, focusPrompt: {
            lookedForPrompt = true
            throw CocoaError(.fileReadUnknown)
        })
        session.completeActivation(generation: token)
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftShoulder, .released, 0.1), profile: profile, testMode: false, emitter: emitter)
        #expect(validated && !lookedForPrompt)
        #expect(session.isReady)
        #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp])
    }

    @Test("An inaccessible Claude prompt still blocks activation and L")
    func claudeActivationRequiresPrompt() throws {
        var session = UnifiedControllerSession(target: .claudeCode)
        let emitter = UnifiedRecorder()
        _ = try session.suspend(emitter: emitter)
        var validated = false
        #expect(throws: (any Error).self) {
            try DesktopActivationPolicy.complete(for: .claudeCode, validateDestination: {
                validated = true
            }, focusPrompt: {
                #expect(validated)
                throw CocoaError(.fileReadUnknown)
            })
        }
        _ = session.process(event(.leftShoulder, .pressed), profile: profile, testMode: false, emitter: emitter)
        #expect(!session.isReady)
        #expect(emitter.keys.isEmpty)
    }

    @Test("Both activation routes reject a destination failure before prompt access")
    func activationDestinationRequired() {
        for target in DesktopTarget.allCases {
            var lookedForPrompt = false
            #expect(throws: (any Error).self) {
                try DesktopActivationPolicy.complete(for: target, validateDestination: {
                    throw CocoaError(.fileReadUnknown)
                }, focusPrompt: { lookedForPrompt = true })
            }
            #expect(!lookedForPrompt)
        }
    }

    @Test("A stale activation completion cannot re-arm a newer transition")
    func staleActivation() throws {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.selectTarget(.claudeCode, testMode: false, emitter: emitter)
        let newer = try session.suspend(emitter: emitter)
        session.completeActivation(generation: newer - 1)
        #expect(!session.isReady)
        session.completeActivation(generation: newer)
        #expect(session.isReady)
    }

    @Test("Disconnect cancels repeats and requires a release before reconnect input")
    func disconnect() throws {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftStickUp, .pressed), profile: profile, testMode: false, emitter: emitter)
        try session.disconnected(emitter: emitter)
        session.completeActivation(generation: session.generation)
        _ = session.process(event(.dpadRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(10), testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        #expect(emitter.scrolls == [.up])
        _ = session.process(event(.dpadRight, .released), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.dpadRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.keys.count == 1)
    }

    @Test("Pane selection releases recording first, cancels deferred output and requires neutral controls")
    func paneTransition() {
        for (direction, side) in [(ControllerInput.leftStickLeft, DesktopPromptSide.left), (.leftStickRight, .right)] {
            var session = UnifiedControllerSession(target: .claudeCode)
            let emitter = UnifiedRecorder()
            for e in [event(.buttonCapture, .pressed), event(.buttonCapture, .released, 0.01),
                event(.leftStickUp, .pressed, 0.02), event(.leftShoulder, .pressed, 0.03),
                event(.leftTrigger, .pressed, 0.04)] {
                _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
            }
            #expect(session.hasDeferredOutput)
            let result = session.process(event(direction, .pressed, 0.05), profile: profile, testMode: false, emitter: emitter)
            #expect(result == .desktopAction(.focusPrompt(side), disposition: .emitted))
            #expect(Array(emitter.trace.suffix(2)) == ["keyUp", "focus:\(side.rawValue)"])
            #expect(session.awaitingNeutral)
            #expect(session.isReady)
            #expect(!session.hasDeferredOutput)
            _ = session.process(event(direction, .pressed, 0.06), profile: profile, testMode: false, emitter: emitter)
            _ = session.advance(to: origin.addingTimeInterval(5), testMode: false, emitter: emitter)
            #expect(emitter.desktopActions == [.focusPrompt(side)])
            #expect(emitter.keys.count == 2)
            #expect(emitter.scrolls == [.up])
            for input in [ControllerInput.leftTrigger, .leftStickUp, .leftShoulder, direction] {
                _ = session.process(event(input, .released, 5.1), profile: profile, testMode: false, emitter: emitter)
            }
            #expect(!session.awaitingNeutral)
            for e in [event(.leftShoulder, .pressed, 6), event(.leftShoulder, .released, 6.1),
                event(.buttonCapture, .pressed, 7), event(.buttonCapture, .released, 7.01)] {
                _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
            }
            _ = session.advance(to: origin.addingTimeInterval(8), testMode: false, emitter: emitter)
            for e in [event(.buttonCapture, .pressed, 9), event(.buttonCapture, .released, 9.01),
                event(.buttonCapture, .pressed, 9.1), event(.buttonCapture, .released, 9.11)] {
                _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
            }
            _ = session.advance(to: origin.addingTimeInterval(10), testMode: false, emitter: emitter)
            #expect(emitter.keys.map(\.1) == [.keyDown, .keyUp, .keyDown, .keyUp, .tap, .tap])
            #expect(emitter.keys.suffix(2).map(\.0) == [profile.mapping(for: .buttonCapture)!.primaryAction!.shortcut!,
                profile.mapping(for: .buttonCapture)!.doubleTapAction!.shortcut!])
            let appSwitch = tripleSwitch(&session, emitter: emitter, starting: 11)
            #expect(appSwitch == .targetChanged(.codex, generation: session.generation))
        }
    }

    @Test("A failed recording release blocks pane focus; a later clean selection recovers")
    func paneCleanupFailure() {
        var session = UnifiedControllerSession(target: .claudeCode)
        let emitter = UnifiedRecorder()
        for input in [ControllerInput.leftShoulder, .leftTrigger] {
            _ = session.process(event(input, .pressed), profile: profile, testMode: false, emitter: emitter)
        }
        emitter.failRelease = true
        let result = session.process(event(.leftStickRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        guard case .desktopAction(_, .failed) = result else { Issue.record("Cleanup failure must block focus"); return }
        #expect(emitter.desktopActions.isEmpty)
        #expect(!session.isReady)
        for input in [ControllerInput.leftShoulder, .leftTrigger, .leftStickRight] {
            _ = session.process(event(input, .released), profile: profile, testMode: false, emitter: emitter)
        }
        emitter.failRelease = false
        _ = session.process(event(.leftTrigger, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftStickRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.desktopActions == [.focusPrompt(.right)])
        #expect(!emitter.held)
    }

    @Test("Explicit pane choice recovers readiness; a stale activation cannot undo a failed newer choice")
    func paneReadiness() throws {
        var session = UnifiedControllerSession(target: .claudeCode)
        let emitter = UnifiedRecorder()
        let old = try session.suspend(emitter: emitter)
        _ = session.process(event(.leftTrigger, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftStickRight, .pressed), profile: profile, testMode: false, emitter: emitter)
        #expect(session.isReady)
        for input in [ControllerInput.leftTrigger, .leftStickRight] {
            _ = session.process(event(input, .released), profile: profile, testMode: false, emitter: emitter)
        }
        emitter.failDesktopAction = true
        _ = session.process(event(.leftTrigger, .pressed), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftStickLeft, .pressed), profile: profile, testMode: false, emitter: emitter)
        session.completeActivation(generation: old)
        #expect(!session.isReady)
        #expect(emitter.desktopActions == [.focusPrompt(.right)])
    }

    @Test("Preview pane selection has no native output")
    func previewPane() {
        var session = UnifiedControllerSession(target: .claudeCode)
        let emitter = UnifiedRecorder()
        _ = session.process(event(.leftTrigger, .pressed), profile: profile, testMode: true, emitter: emitter)
        let result = session.process(event(.leftStickRight, .pressed), profile: profile, testMode: true, emitter: emitter)
        #expect(result == .desktopAction(.focusPrompt(.right), disposition: .suppressedByTestMode))
        #expect(emitter.desktopActions.isEmpty)
        #expect(emitter.keys.isEmpty)
    }

    @Test("Codex Fn and ordinary Claude horizontal input retain their profile mappings")
    func paneMappingBoundaries() {
        for (target, fn) in [(DesktopTarget.codex, true), (.claudeCode, false)] {
            var session = UnifiedControllerSession(target: target)
            let emitter = UnifiedRecorder()
            if fn { _ = session.process(event(.leftTrigger, .pressed), profile: profile, testMode: false, emitter: emitter) }
            _ = session.process(event(.leftStickLeft, .pressed), profile: profile, testMode: false, emitter: emitter)
            #expect(emitter.desktopActions.isEmpty)
            #expect(emitter.keys.map(\.0) == [profile.mapping(for: .leftStickLeft)!.action(for: fn ? .function : .primary)!.shortcut!])
        }
    }

    @Test("Holding a direction before ZL does not retroactively select a pane")
    func paneChordOrder() {
        var session = UnifiedControllerSession(target: .claudeCode)
        let emitter = UnifiedRecorder()
        for input in [ControllerInput.leftStickLeft, .leftTrigger, .leftStickLeft] {
            _ = session.process(event(input, .pressed), profile: profile, testMode: false, emitter: emitter)
        }
        #expect(emitter.desktopActions.isEmpty)
        _ = session.process(event(.leftStickLeft, .released), profile: profile, testMode: false, emitter: emitter)
        _ = session.process(event(.leftStickLeft, .pressed), profile: profile, testMode: false, emitter: emitter)
        #expect(emitter.desktopActions == [.focusPrompt(.left)])
    }


    private var newChat: Shortcut { Shortcut(keyCode: 45, displayLabel: "N", modifiers: [.command]) }
    private var archive: Shortcut { Shortcut(keyCode: 0, displayLabel: "A", modifiers: [.command, .shift]) }
    private var closeTab: Shortcut { Shortcut(keyCode: 13, displayLabel: "W", modifiers: [.command]) }
    private var longPressProfile: MappingProfile {
        var profile = self.profile
        profile.update(InputMapping(input: .buttonMinus, primaryAction: .tap(newChat),
            functionAction: .tap(closeTab), longPressAction: .tap(archive)))
        return profile
    }

    @Test("A short press emits the primary tap on release, not on press")
    func longPressShort() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.buttonMinus, .pressed), profile: longPressProfile, testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        _ = session.process(event(.buttonMinus, .released, 1.9), profile: longPressProfile, testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(5), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [newChat])
        #expect(!session.hasDeferredOutput)
    }

    @Test("Holding past two seconds emits only the long-press action, once")
    func longPressLong() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        _ = session.process(event(.buttonMinus, .pressed), profile: longPressProfile, testMode: false, emitter: emitter)
        #expect(session.hasDeferredOutput)
        _ = session.advance(to: origin.addingTimeInterval(1.99), testMode: false, emitter: emitter)
        #expect(emitter.keys.isEmpty)
        _ = session.advance(to: origin.addingTimeInterval(2), testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(3), testMode: false, emitter: emitter)
        _ = session.process(event(.buttonMinus, .released, 3.5), profile: longPressProfile, testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [archive])
        #expect(!session.hasDeferredOutput)
    }

    @Test("Long press combines with double tap; a held second tap becomes the long press")
    func longPressWithDoubleTap() {
        var profile = longPressProfile
        var minus = profile.mapping(for: .buttonMinus)!
        minus.doubleTapAction = .tap(closeTab)
        profile.update(minus)
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.buttonMinus, .pressed), event(.buttonMinus, .released, 0.05),
            event(.buttonMinus, .pressed, 0.15)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(2.2), testMode: false, emitter: emitter)
        _ = session.process(event(.buttonMinus, .released, 2.3), profile: profile, testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(4), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [archive])

        for e in [event(.buttonMinus, .pressed, 5), event(.buttonMinus, .released, 5.05)] {
            _ = session.process(e, profile: profile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(6), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [archive, newChat])
    }

    @Test("Fn keeps its own action for long-press inputs, and a switch cancels a pending long press")
    func longPressFunctionLayerAndCancel() {
        var session = UnifiedControllerSession()
        let emitter = UnifiedRecorder()
        for e in [event(.leftTrigger, .pressed), event(.buttonMinus, .pressed, 0.1)] {
            _ = session.process(e, profile: longPressProfile, testMode: false, emitter: emitter)
        }
        _ = session.advance(to: origin.addingTimeInterval(3), testMode: false, emitter: emitter)
        for e in [event(.buttonMinus, .released, 3.1), event(.leftTrigger, .released, 3.2)] {
            _ = session.process(e, profile: longPressProfile, testMode: false, emitter: emitter)
        }
        #expect(emitter.keys.map(\.0) == [closeTab])

        _ = session.process(event(.buttonMinus, .pressed, 4), profile: longPressProfile, testMode: false, emitter: emitter)
        _ = session.selectTarget(.claudeCode, testMode: false, emitter: emitter)
        #expect(!session.hasDeferredOutput)
        session.completeActivation(generation: session.generation)
        _ = session.process(event(.buttonMinus, .released, 4.1), profile: longPressProfile, testMode: false, emitter: emitter)
        _ = session.advance(to: origin.addingTimeInterval(10), testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [closeTab])
    }

    @Test("Long-press actions must be taps within 500–5000 ms")
    func longPressValidation() throws {
        var profile = longPressProfile
        try profile.validate()
        var minus = profile.mapping(for: .buttonMinus)!
        minus.longPressDurationMilliseconds = 300
        profile.update(minus)
        #expect(throws: ProfileValidationError.invalidLongPressDuration(input: .buttonMinus, milliseconds: 300)) {
            try profile.validate()
        }
        minus.longPressDurationMilliseconds = nil
        minus.longPressAction = .hold(archive)
        profile.update(minus)
        #expect(throws: ProfileValidationError.invalidLongPressAction(.buttonMinus)) { try profile.validate() }
    }
}

private final class UnifiedRecorder: HeldShortcutRecovering, DesktopUIActionEmitting {
    var keys: [(Shortcut, ShortcutEmissionPhase)] = []
    var scrolls: [ScrollCommand] = []
    var failRelease = false
    var recoveries = 0
    var held = false
    var desktopActions: [DesktopUIAction] = []
    var trace: [String] = []
    var failDesktopAction = false
    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws {
        if phase == .keyUp && failRelease { throw CocoaError(.fileWriteUnknown) }
        keys.append((shortcut, phase))
        trace.append(String(describing: phase))
        if phase == .keyDown { held = true }
        if phase == .keyUp { held = false }
    }
    func emit(_ command: ScrollCommand) throws { scrolls.append(command) }
    func emit(_ action: DesktopUIAction) throws {
        #expect(!held)
        if failDesktopAction { throw CocoaError(.featureUnsupported) }
        desktopActions.append(action)
        if case .focusPrompt(let side) = action { trace.append("focus:\(side.rawValue)") }
    }
    func releaseHeldKeys() throws {
        recoveries += 1
        if failRelease { throw CocoaError(.fileWriteUnknown) }
        held = false
    }
}

@Suite("Unified profile isolation and desktop policy")
struct UnifiedProfileTests {
    @Test("Imported ChatGPT bindings navigate sidebar chats rather than tabs, preserving Claude and legacy bytes")
    func currentChatGPTBindings() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let store = UnifiedProfileStore(applicationSupport: support)
        let legacy = ProfileStore(profileURL: store.legacyProfileURL)
        var imported = MappingProfile.starter
        let oldUp = Shortcut(keyCode: 33, displayLabel: "[", modifiers: [.command, .shift])
        let oldDown = Shortcut(keyCode: 30, displayLabel: "]", modifiers: [.command, .shift])
        imported.update(InputMapping(input: .leftStickUp, primaryAction: .scrollUp, functionAction: .tap(oldUp)))
        imported.update(InputMapping(input: .leftStickDown, primaryAction: .scrollDown, functionAction: .tap(oldDown)))
        try legacy.save(imported)
        let before = try Data(contentsOf: store.legacyProfileURL)
        let chatGPT = store.load(for: .codex).profile
        let claude = store.load(for: .claudeCode).profile
        let newUp = Shortcut(keyCode: 33, displayLabel: "[", modifiers: [.command, .option])
        let newDown = Shortcut(keyCode: 30, displayLabel: "]", modifiers: [.command, .option])
        #expect(chatGPT.mapping(for: .leftStickUp)?.functionAction == .tap(newUp))
        #expect(chatGPT.mapping(for: .leftStickDown)?.functionAction == .tap(newDown))
        #expect(claude.mapping(for: .leftStickUp)?.functionAction == .tap(oldUp))
        #expect(claude.mapping(for: .leftStickDown)?.functionAction == .tap(oldDown))
        #expect(chatGPT.mapping(for: .dpadLeft)?.functionAction == .tap(Shortcut(keyCode: 1, displayLabel: "S", modifiers: [.command, .shift])))
        #expect(chatGPT.mapping(for: .dpadRight)?.functionAction == .tap(Shortcut(keyCode: 14, displayLabel: "E", modifiers: [.command, .shift])))
        #expect(chatGPT.mapping(for: .buttonY)?.functionAction == chatGPT.mapping(for: .dpadLeft)?.functionAction)
        #expect(chatGPT.mapping(for: .buttonA)?.functionAction == chatGPT.mapping(for: .dpadRight)?.functionAction)
        #expect(try Data(contentsOf: store.legacyProfileURL) == before)

        let emitter = UnifiedRecorder()
        var session = UnifiedControllerSession()
        _ = session.process(ControllerEvent(input: .leftTrigger, phase: .pressed), profile: chatGPT, testMode: false, emitter: emitter)
        _ = session.process(ControllerEvent(input: .leftStickUp, phase: .pressed), profile: chatGPT, testMode: false, emitter: emitter)
        _ = session.process(ControllerEvent(input: .leftStickUp, phase: .released), profile: chatGPT, testMode: false, emitter: emitter)
        _ = session.process(ControllerEvent(input: .leftStickDown, phase: .pressed), profile: chatGPT, testMode: false, emitter: emitter)
        #expect(emitter.keys.map(\.0) == [newUp, newDown])
        #expect(chatGPT.mapping(for: .leftStickUp)?.primaryAction == .scrollUp)
        #expect(chatGPT.mapping(for: .leftStickDown)?.primaryAction == .scrollDown)
    }

    @Test("Custom imported actions and saved target profiles are never overwritten by shortcut compatibility")
    func preserveCustomChatGPTBindings() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let store = UnifiedProfileStore(applicationSupport: support)
        var custom = MappingProfile.starter
        let customAction = MappingAction.tap(Shortcut(keyCode: 45, displayLabel: "N", modifiers: [.command]))
        custom.update(InputMapping(input: .leftStickUp, primaryAction: .scrollUp, functionAction: customAction))
        #expect(store.adaptImportedBaseline(custom, for: .codex).mapping(for: .leftStickUp)?.functionAction == customAction)
        let explicitTab = MappingAction.tap(Shortcut(keyCode: 33, displayLabel: "[", modifiers: [.command, .shift]))
        custom.update(InputMapping(input: .leftStickUp, primaryAction: .scrollUp, functionAction: explicitTab))
        try store.save(custom, for: .codex)
        #expect(store.load(for: .codex).profile.mapping(for: .leftStickUp)?.functionAction == explicitTab)
    }

    @Test("Claude's D-pad right long press sends ⌘Return; Codex and custom bindings are untouched")
    func claudeConfirmLongPress() throws {
        let store = UnifiedProfileStore(applicationSupport: FileManager.default.temporaryDirectory)
        let commandReturn = MappingAction.tap(Shortcut(keyCode: 36, displayLabel: "Return", modifiers: [.command]))
        let claude = store.adaptImportedBaseline(.starter, for: .claudeCode)
        try claude.validate()
        #expect(claude.mapping(for: .dpadRight)?.longPressAction == commandReturn)
        #expect(store.adaptImportedBaseline(.starter, for: .codex).mapping(for: .dpadRight)?.longPressAction == nil)
        var custom = MappingProfile.starter
        let other = MappingAction.tap(Shortcut(keyCode: 53, displayLabel: "Escape"))
        custom.update(InputMapping(input: .dpadRight, primaryAction: other))
        #expect(store.adaptImportedBaseline(custom, for: .claudeCode).mapping(for: .dpadRight)?.longPressAction == nil)
    }

    @Test("Bundled startup uses its standard domain instead of the forbidden same-name suite")
    func bundledPreferences() {
        let defaults = UnifiedPreferences.make(bundleIdentifier: UnifiedPreferences.domain)
        #expect(defaults === UserDefaults.standard)
        #expect(UnifiedPreferences.make(bundleIdentifier: "test-runner") != nil)
    }

    @Test("Initial import and separate target saves never modify legacy bytes")
    func isolatedStorage() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let unified = UnifiedProfileStore(applicationSupport: support)
        let legacy = ProfileStore(profileURL: unified.legacyProfileURL)
        var source = MappingProfile.starter
        source.name = "Actual saved layout"
        source.update(InputMapping(input: .leftTrigger,
            primaryAction: .tap(Shortcut(keyCode: 45, displayLabel: "N", modifiers: [.command]))))
        source.update(InputMapping(input: .buttonCapture,
            primaryAction: .tap(Shortcut(keyCode: 124, displayLabel: "Right Arrow", modifiers: [.control, .option])),
            doubleTapAction: .tap(Shortcut(keyCode: 123, displayLabel: "Left Arrow", modifiers: [.control, .option]))))
        try legacy.save(source)
        let original = try Data(contentsOf: legacy.profileURL)
        let codex = unified.load(for: .codex).profile
        #expect(codex.name == source.name)
        #expect(codex.mapping(for: .buttonCapture) == source.mapping(for: .buttonCapture))
        #expect(codex.mapping(for: .buttonSL)?.primaryAction == nil)
        #expect(codex.mapping(for: .leftTrigger)?.primaryAction == .functionLayer)
        #expect(!FileManager.default.fileExists(atPath: unified.directory.path))
        try unified.save(codex, for: .codex)
        var claude = unified.load(for: .claudeCode).profile
        claude.name = "Claude-specific edits"
        try unified.save(claude, for: .claudeCode)
        #expect(unified.load(for: .codex).profile.name == source.name)
        #expect(unified.load(for: .claudeCode).profile.name == claude.name)
        #expect(try Data(contentsOf: legacy.profileURL) == original)
        #expect(unified.store(for: .codex).profileURL != unified.store(for: .claudeCode).profileURL)
    }

    @Test("Corrupt unified profiles are preserved rather than replaced on load")
    func corruptProfile() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: support) }
        let unified = UnifiedProfileStore(applicationSupport: support)
        try FileManager.default.createDirectory(at: unified.directory, withIntermediateDirectories: true)
        let bad = Data("invalid JSON".utf8)
        try bad.write(to: unified.store(for: .codex).profileURL)
        #expect(unified.load(for: .codex).recoveryMessage != nil)
        #expect(try Data(contentsOf: unified.store(for: .codex).profileURL) == bad)
    }

    @Test("Code page policy rejects Chat titles and unrelated hosts")
    func codePolicy() {
        #expect(DesktopAccessibilityPolicy.isCodePage(title: "", url: "", selectedCode: true))
        #expect(DesktopAccessibilityPolicy.isCodePage(title: "", url: "https://claude.ai/epitaxy/project/test", selectedCode: false))
        #expect(!DesktopAccessibilityPolicy.isCodePage(title: "Claude Code instructions in a chat", url: "https://claude.ai/chat/test", selectedCode: false))
        #expect(!DesktopAccessibilityPolicy.isCodePage(title: "Claude Code", url: "https://example.com/code", selectedCode: false))
        #expect(DesktopAccessibilityPolicy.isPrompt("提示词"))
        #expect(DesktopAccessibilityPolicy.isConversation("对话消息"))
    }

    @Test("Outer Code URL is usable without selector state; Chat cannot use a stale Code selection")
    func codeRouteOutranksSelector() {
        let routes = ["/code", "/code/session/test", "/epitaxy/project/test?thread=example"]
        for route in routes {
            #expect(DesktopAccessibilityPolicy.isCodePage(title: "", url: "https://claude.ai\(route)", selectedCode: false))
        }
        #expect(!DesktopAccessibilityPolicy.isCodePage(title: "Claude Code", url: "https://claude.ai/chat/test", selectedCode: true))
        #expect(!DesktopAccessibilityPolicy.isCodePage(title: "Claude Code", url: "https://example.com/code", selectedCode: true))
        #expect(!DesktopAccessibilityPolicy.isCodePage(title: "Claude Code", url: "", selectedCode: false))
    }

    @Test("Pane geometry selects spatial sides and rejects missing or ambiguous layouts")
    func paneGeometry() {
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let left = CGRect(x: 280, y: 800, width: 400, height: 50)
        let right = CGRect(x: 720, y: 800, width: 400, height: 50)
        let offscreen = CGRect(x: 1500, y: 800, width: 400, height: 50)
        #expect(DesktopPromptSelection.index(for: .left, frames: [right, offscreen, left], window: bounds) == 2)
        #expect(DesktopPromptSelection.index(for: .right, frames: [right, offscreen, left], window: bounds) == 0)
        for frames in [[left], [left, right, left], [left, left],
            [left, CGRect(x: 280, y: 700, width: 400, height: 50)]] {
            #expect(DesktopPromptSelection.index(for: .right, frames: frames, window: bounds) == nil)
        }
    }

    @Test("Known desktop operations translate while imported Codex keys remain exact")
    func desktopTranslation() {
        let panel = Shortcut(keyCode: 11, displayLabel: "B", modifiers: [.command, .option])
        #expect(DesktopShortcutResolver.resolve(panel, for: .codex) == .keyboard(panel))
        #expect(DesktopShortcutResolver.resolve(panel, for: .claudeCode)
            == .keyboard(Shortcut(keyCode: 2, displayLabel: "D", modifiers: [.command, .shift])))
        let capture = Shortcut(keyCode: 124, displayLabel: "Right Arrow", modifiers: [.control, .option])
        #expect(DesktopShortcutResolver.resolve(capture, for: .codex) == .keyboard(capture))
        #expect(DesktopShortcutResolver.resolve(capture, for: .claudeCode) == .interface(.adjustEffort(increase: true)))
        let custom = Shortcut(keyCode: 45, displayLabel: "N", modifiers: [.command])
        #expect(DesktopShortcutResolver.resolve(custom, for: .claudeCode) == .keyboard(custom))
    }
}
