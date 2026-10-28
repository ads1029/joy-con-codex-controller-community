import Foundation

public enum UnifiedSessionResult: Equatable, Sendable {
    case mapping(MappingResult)
    case targetChanged(DesktopTarget, generation: UInt64)
    case desktopAction(DesktopUIAction, disposition: MappingDisposition)
    case suppressed
    case failed(String)
}

/// One clock-driven session owns all deferred output, so a switch can cancel
/// taps, repeats and holds as a single operation. No timers emit independently.
public struct UnifiedControllerSession: Sendable {
    public private(set) var target: DesktopTarget
    public private(set) var generation: UInt64 = 0
    public private(set) var isReady = true
    public private(set) var heldInputs = Set<ControllerInput>()
    public private(set) var awaitingNeutral = false
    public var isFunctionLayerActive: Bool { engine.isFunctionLayerActive }
    public var hasDeferredOutput: Bool {
        !pendingTaps.isEmpty || !repeats.isEmpty || longPresses.values.contains { !$0.fired }
    }

    private var engine = MappingEngine()
    private var taps = TapSequenceRecognizer()
    private var switchTaps = ZLTripleTapRecognizer()
    private var functionCaptureHeld = false
    private var functionLayerPresses = Set<ControllerInput>()
    private struct PendingTap: Sendable {
        let event: ControllerEvent
        let action: MappingAction?
        let deadline: Date
    }
    private struct Repeating: Sendable {
        let event: ControllerEvent
        let action: MappingAction
        let plan: RepeatPlan
        var deadline: Date
    }
    private struct LongPress: Sendable {
        let event: ControllerEvent
        let action: MappingAction?
        let deadline: Date
        var fired = false
    }
    private var pendingTaps: [ControllerInput: PendingTap] = [:]
    private var longPresses: [ControllerInput: LongPress] = [:]
    private var repeats: [ControllerInput: Repeating] = [:]

    public init(target: DesktopTarget = .codex) { self.target = target }

    public func promptSelection(for event: ControllerEvent) -> DesktopPromptSide? {
        guard target == .claudeCode, !awaitingNeutral, event.phase == .pressed,
              heldInputs.contains(.leftTrigger) else { return nil }
        switch event.input {
        case .leftStickLeft: return .left
        case .leftStickRight: return .right
        default: return nil
        }
    }

    public mutating func process(_ event: ControllerEvent, profile: MappingProfile,
        testMode: Bool, emitter: any ShortcutEmitting) -> UnifiedSessionResult {
        guard event.input != .buttonSL && event.input != .buttonSR else {
            switchTaps.reset()
            return .suppressed
        }
        let freshPress: Bool
        switch event.phase {
        case .pressed: freshPress = heldInputs.insert(event.input).inserted
        case .released:
            heldInputs.remove(event.input)
            repeats.removeValue(forKey: event.input)
            freshPress = false
        }
        if awaitingNeutral {
            switchTaps.reset()
            if heldInputs.isEmpty { awaitingNeutral = false }
            return .suppressed
        }
        if switchTaps.process(event, freshPress: freshPress,
            otherControlsHeld: heldInputs.contains(where: { $0 != .leftTrigger })) {
            return selectTarget(target.other, testMode: testMode, emitter: emitter)
        }
        // The old chord is disabled. Consume its release even if ZL is released
        // first, so it cannot leak into ordinary Capture single/double recognition.
        if event.input == .buttonCapture {
            if event.phase == .pressed, freshPress, heldInputs.contains(.leftTrigger) {
                functionCaptureHeld = true
                taps.cancel(.buttonCapture)
                pendingTaps.removeValue(forKey: .buttonCapture)
                longPresses.removeValue(forKey: .buttonCapture)
                return .suppressed
            }
            if functionCaptureHeld {
                if event.phase == .released { functionCaptureHeld = false }
                return .suppressed
            }
        }
        if freshPress, let side = promptSelection(for: event) {
            return selectPrompt(side, testMode: testMode, emitter: emitter)
        }
        guard isReady else { return .suppressed }
        if event.phase == .pressed && !freshPress { return .suppressed }

        // Under Fn, deferred-tap inputs keep their ordinary Fn action and release.
        if event.phase == .pressed, engine.isFunctionLayerActive,
           let mapping = profile.mapping(for: event.input),
           mapping.usesDeferredTaps, mapping.functionAction != nil {
            functionLayerPresses.insert(event.input)
        }
        if functionLayerPresses.contains(event.input) {
            if event.phase == .released { functionLayerPresses.remove(event.input) }
            return .mapping(engine.process(event, profile: profile, testMode: testMode, emitter: emitter))
        }
        if let mapping = profile.mapping(for: event.input), mapping.usesDeferredTaps {
            return processTap(event, mapping: mapping, testMode: testMode, emitter: emitter)
        }
        let result = engine.process(event, profile: profile, testMode: testMode, emitter: emitter)
        if event.phase == .pressed, result.disposition == .emitted,
           let action = result.action, let plan = ControllerRepeatPolicy.plan(for: event.input, action: action) {
            repeats[event.input] = Repeating(event: event, action: action, plan: plan,
                deadline: event.timestamp.addingTimeInterval(Double(plan.initialDelayMilliseconds) / 1_000))
        }
        return .mapping(result)
    }

    public mutating func selectTarget(_ newTarget: DesktopTarget, testMode: Bool,
        emitter: any ShortcutEmitting) -> UnifiedSessionResult {
        guard newTarget != target else { return .suppressed }
        do {
            try suspend(emitter: emitter)
            target = newTarget
            isReady = testMode
            return .targetChanged(target, generation: generation)
        } catch { return .failed(error.localizedDescription) }
    }

    private mutating func selectPrompt(_ side: DesktopPromptSide, testMode: Bool,
        emitter: any ShortcutEmitting) -> UnifiedSessionResult {
        let action = DesktopUIAction.focusPrompt(side)
        do {
            // A pane change owns the same cleanup/neutral boundary as an app
            // change. Old recording mouse-up must precede focusing a new prompt.
            let token = try suspend(emitter: emitter)
            if !testMode {
                guard let desktop = emitter as? any DesktopUIActionEmitting else {
                    return .desktopAction(action, disposition: .failed("Prompt selection is unavailable in this emitter."))
                }
                try desktop.emit(action)
            }
            completeActivation(generation: token)
            return .desktopAction(action, disposition: testMode ? .suppressedByTestMode : .emitted)
        } catch {
            return .desktopAction(action, disposition: .failed(error.localizedDescription))
        }
    }

    /// Releases to the OLD emitter destination before the caller changes it.
    @discardableResult
    public mutating func suspend(emitter: any ShortcutEmitting) throws -> UInt64 {
        generation &+= 1
        isReady = false
        awaitingNeutral = !heldInputs.isEmpty
        repeats.removeAll()
        pendingTaps.removeAll()
        longPresses.removeAll()
        taps = TapSequenceRecognizer()
        switchTaps.reset()
        functionCaptureHeld = false
        functionLayerPresses.removeAll()
        var firstError: Error?
        do { try engine.releaseAll(emitter: emitter) } catch { firstError = error }
        if let recovering = emitter as? any HeldShortcutRecovering {
            do { try recovering.releaseHeldKeys() } catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
        return generation
    }

    public mutating func completeActivation(generation token: UInt64) {
        guard token == generation else { return }
        isReady = true
    }

    /// Keep the neutral barrier accurate while an external window operation owns
    /// the UI. No chord, tap, repeat or target switch may escape this gate.
    public mutating func observeWhileSuspended(_ event: ControllerEvent) {
        switchTaps.reset()
        if event.phase == .pressed { heldInputs.insert(event.input) }
        else { heldInputs.remove(event.input) }
        awaitingNeutral = !heldInputs.isEmpty
    }

    /// Changing preview/live mode does not require application activation.
    /// The emitter still validates the selected foreground target for every new
    /// output. Preserve cleanup failures and the all-controls-neutral barrier.
    public mutating func outputModeChanged(emitter: any ShortcutEmitting) throws {
        let token = try suspend(emitter: emitter)
        completeActivation(generation: token)
    }

    public mutating func holdForActivation(_ event: ControllerEvent,
        emitter: any ShortcutEmitting) throws -> UInt64 {
        if event.phase == .pressed { heldInputs.insert(event.input) }
        else { heldInputs.remove(event.input) }
        return try suspend(emitter: emitter)
    }

    public mutating func disconnected(emitter: any ShortcutEmitting) throws {
        try suspend(emitter: emitter)
        heldInputs.removeAll()
        awaitingNeutral = true // Discard the first held control until a release is observed.
    }

    public mutating func advance(to now: Date, testMode: Bool,
        emitter: any ShortcutEmitting) -> [UnifiedSessionResult] {
        guard isReady, !awaitingNeutral else { return [] }
        var results: [UnifiedSessionResult] = []
        for input in pendingTaps.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let pending = pendingTaps[input], now >= pending.deadline else { continue }
            _ = taps.expire(input, at: now)
            pendingTaps.removeValue(forKey: input)
            results.append(emitTap(pending.action, event: pending.event, testMode: testMode, emitter: emitter))
        }
        for input in longPresses.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard var press = longPresses[input], !press.fired, now >= press.deadline else { continue }
            // Fire while still held; the eventual release is consumed, so the
            // short-press (and any second-tap) output never follows.
            press.fired = true
            longPresses[input] = press
            taps.cancel(input)
            pendingTaps.removeValue(forKey: input)
            results.append(emitTap(press.action, event: press.event, testMode: testMode, emitter: emitter))
        }
        for input in repeats.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard var entry = repeats[input], now >= entry.deadline else { continue }
            guard !testMode else { repeats.removeValue(forKey: input); continue }
            do {
                switch entry.plan.output {
                case let .keyboardTap(shortcut): try emitter.emit(shortcut, phase: .tap)
                case let .scroll(command): try emitter.emit(command)
                }
                // Skip missed ticks instead of replaying a burst after a busy run loop.
                entry.deadline = now.addingTimeInterval(Double(entry.plan.intervalMilliseconds) / 1_000)
                repeats[input] = entry
            } catch {
                repeats.removeValue(forKey: input)
                results.append(.failed(error.localizedDescription))
            }
        }
        return results
    }

    private mutating func processTap(_ event: ControllerEvent, mapping: InputMapping,
        testMode: Bool, emitter: any ShortcutEmitting) -> UnifiedSessionResult {
        if mapping.longPressAction != nil {
            switch event.phase {
            case .pressed:
                let duration = Double(mapping.resolvedLongPressDurationMilliseconds) / 1_000
                longPresses[event.input] = LongPress(event: event, action: mapping.longPressAction,
                    deadline: event.timestamp.addingTimeInterval(duration))
            case .released:
                guard let press = longPresses.removeValue(forKey: event.input), !press.fired else {
                    taps.cancel(event.input)
                    return .suppressed
                }
            }
            if mapping.doubleTapAction == nil {
                // Without a double-tap there is nothing to wait for after release.
                return event.phase == .released
                    ? emitTap(mapping.primaryAction, event: event, testMode: testMode, emitter: emitter)
                    : .suppressed
            }
        }
        let interval = mapping.resolvedDoubleTapIntervalMilliseconds
        if event.phase == .pressed, taps.expire(event.input, at: event.timestamp),
           let pending = pendingTaps.removeValue(forKey: event.input) {
            _ = emitTap(pending.action, event: pending.event, testMode: testMode, emitter: emitter)
        }
        switch event.phase {
        case .pressed:
            if taps.press(event.input, at: event.timestamp) == .secondTap {
                pendingTaps.removeValue(forKey: event.input)
            }
            return .suppressed
        case .released:
            switch taps.release(event.input, at: event.timestamp, intervalMilliseconds: interval) {
            case .singlePending:
                pendingTaps[event.input] = PendingTap(event: event, action: mapping.primaryAction,
                    deadline: event.timestamp.addingTimeInterval(Double(interval) / 1_000))
                return .suppressed
            case .doubleTap:
                return emitTap(mapping.doubleTapAction, event: event, testMode: testMode, emitter: emitter)
            case .ignored: return .suppressed
            }
        }
    }

    private func emitTap(_ action: MappingAction?, event: ControllerEvent,
        testMode: Bool, emitter: any ShortcutEmitting) -> UnifiedSessionResult {
        guard let action, action.kind == .tap, let shortcut = action.shortcut else { return .suppressed }
        let disposition: MappingDisposition
        if testMode { disposition = .suppressedByTestMode }
        else {
            do { try emitter.emit(shortcut, phase: .tap); disposition = .emitted }
            catch { return .failed(error.localizedDescription) }
        }
        return .mapping(MappingResult(event: event, layer: .primary, action: action, disposition: disposition))
    }
}
