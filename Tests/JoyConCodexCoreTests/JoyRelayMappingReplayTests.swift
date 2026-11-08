import Foundation
import Testing
@testable import JoyConCodexCore

@Suite("JoyRelay mapping replay")
struct JoyRelayMappingReplayTests {
    @Test("Left Joy-Con report-only L/L3/ZL: dictation, Fn and switch on third release",
          arguments: [false, true])
    func leftJoyConReportReplay(preview: Bool) throws {
        let support = temporarySupport()
        defer { try? FileManager.default.removeItem(at: support) }
        let store = UnifiedProfileStore(applicationSupport: support)
        var legacy = MappingProfile.starter
        legacy.update(InputMapping(input: .leftStickPress, primaryAction: .scrollToBottom,
            functionAction: .tap(Shortcut(keyCode: 18, displayLabel: "1", modifiers: [.command]))))
        try ProfileStore(profileURL: store.legacyProfileURL).save(legacy)
        let original = try Data(contentsOf: store.legacyProfileURL)
        let replay = MappingReplay(target: .codex, profile: store.load(for: .codex).profile, preview: preview)
        var hid = LeftJoyConSupplementState()

        func frame(_ time: Double, id: UInt8 = 0x30, left: UInt8 = 0, shared: UInt8 = 0) -> [UnifiedSessionResult] {
            // 49-byte full-report shape: shared buttons at byte 4, L/ZL at byte 5.
            var bytes = [UInt8](repeating: 0, count: 49)
            bytes[0] = id
            bytes[1] = 0x3d
            bytes[2] = 0x4e
            bytes[4] = shared
            bytes[5] = left
            return (hid.processReport(reportID: UInt32(id), bytes: bytes) ?? []).map {
                replay.edge($0.input, $0.phase, time)
            }
        }

        #expect(frame(0).isEmpty)
        let l = try #require(frame(0.1, left: 0x40).first)
        if case let .mapping(result) = l {
            #expect(result.action?.kind == .hold)
            #expect(result.shortcut?.keyCode == 2)
            #expect(result.disposition == (preview ? .suppressedByTestMode : .emitted))
        } else {
            Issue.record("Raw L did not resolve to a mapping: \(l)")
        }
        #expect(frame(0.15, left: 0x40).isEmpty) // No duplicate key-down.
        #expect(frame(0.20, id: 0x21).isEmpty) // No early key-up on a command reply.
        #expect(replay.output == (preview ? [] : [.key(2, [.control, .shift], .keyDown)]))
        _ = frame(0.25)
        _ = frame(1, shared: 0x08)
        _ = frame(1.1)
        _ = frame(2, left: 0x80, shared: 0x08)
        #expect(replay.session.isFunctionLayerActive)
        _ = frame(2.5)
        #expect(!replay.session.isFunctionLayerActive)
        #expect(replay.output == (preview ? [] : [
            .key(2, [.control, .shift], .keyDown), .key(2, [.control, .shift], .keyUp),
            .scroll(.toBottom), .key(18, [.command], .tap),
        ]))

        for start in [3.0, 3.15, 3.30] {
            _ = frame(start, left: 0x80)
            #expect(replay.session.target == .codex)
            let release = frame(start + 0.05)
            if start < 3.30 {
                #expect(replay.session.target == .codex)
            } else {
                #expect(release == [.targetChanged(.claudeCode, generation: 1)])
            }
        }
        #expect(replay.session.target == .claudeCode)
        #expect(replay.session.heldInputs.isEmpty)
        #expect(!replay.session.isFunctionLayerActive)
        #expect(!replay.session.hasDeferredOutput)
        #expect(try Data(contentsOf: store.legacyProfileURL) == original)
        #expect(!FileManager.default.fileExists(atPath: store.directory.path))
    }

    @Test("Switch Pro navigation and shared controls respect target, Fn and Test Mode",
          arguments: DesktopTarget.allCases, [false, true])
    func switchProReplay(target: DesktopTarget, preview: Bool) throws {
        let support = temporarySupport()
        defer { try? FileManager.default.removeItem(at: support) }
        let store = UnifiedProfileStore(applicationSupport: support)
        var profile = MappingProfile.starter
        // Explicitly customized bindings, not claims about a fresh install.
        profile.update(InputMapping(input: .buttonCapture,
            primaryAction: .tap(Shortcut(keyCode: 126, displayLabel: "Up Arrow", modifiers: [.control])),
            doubleTapAction: .tap(Shortcut(keyCode: 125, displayLabel: "Down Arrow", modifiers: [.control]))))
        profile.update(InputMapping(input: .rightShoulder,
            primaryAction: .tap(Shortcut(keyCode: 53, displayLabel: "Escape"))))
        try store.save(profile, for: target)
        let url = store.store(for: target).profileURL
        let original = try Data(contentsOf: url)
        let replay = MappingReplay(target: target, profile: store.load(for: target).profile, preview: preview)
        let pro: ControllerEventLayout = .switchProRightHand

        replay.tap(.rightShoulder, 0, layout: pro)
        _ = replay.edge(.leftTrigger, .pressed, 1)
        #expect(replay.session.isFunctionLayerActive)
        replay.tap(.rightTrigger, 1.10, layout: pro)
        _ = replay.edge(.leftTrigger, .released, 1.50)
        _ = replay.edge(.rightStickUp, .pressed, 2, layout: pro)
        replay.advance(2.40)
        _ = replay.edge(.rightStickUp, .released, 2.45, layout: pro)
        replay.advance(2.80) // Must not emit a third scroll after release.
        replay.tap(.rightStickDown, 3, layout: pro)
        replay.tap(.rightStickPress, 4, layout: pro)
        replay.tap(.rightStickLeft, 5, layout: pro)
        replay.tap(.rightStickRight, 6, layout: pro)

        replay.tap(.rightShoulder, 7) // Untagged controller retains its saved R binding.
        replay.tap(.leftShoulder, 8)
        replay.tap(.buttonCapture, 9)
        replay.advance(9.75)
        replay.tap(.buttonCapture, 10)
        replay.tap(.buttonCapture, 10.15)
        replay.advance(10.75)

        // Fn+Capture must not leak an ordinary tap or the former switch gesture.
        _ = replay.edge(.leftTrigger, .pressed, 11)
        _ = replay.edge(.buttonCapture, .pressed, 11.1)
        _ = replay.edge(.leftTrigger, .released, 11.5)
        _ = replay.edge(.buttonCapture, .released, 11.6)
        replay.advance(12)

        let modifiers: Set<KeyModifier> = target == .codex ? [.command, .option] : [.command, .shift]
        let horizontal: [ReplayOutput] = target == .codex
            ? [.key(123, [], .tap), .key(124, [], .tap)]
            : [.desktop(.focusPrompt(.left)), .desktop(.focusPrompt(.right))]
        let expected: [ReplayOutput] = [
            .key(30, modifiers, .tap), .key(33, modifiers, .tap),
            .scroll(.up), .scroll(.up), .scroll(.down), .scroll(.toBottom),
        ] + horizontal + [
            .key(53, [], .tap),
            .key(2, [.control, .shift], .keyDown), .key(2, [.control, .shift], .keyUp),
            .key(126, [.control], .tap), .key(125, [.control], .tap),
        ]
        #expect(replay.output == (preview ? [] : expected))
        #expect(replay.session.target == target)
        #expect(replay.session.heldInputs.isEmpty)
        #expect(!replay.session.isFunctionLayerActive)
        #expect(!replay.session.awaitingNeutral)
        #expect(!replay.session.hasDeferredOutput)
        #expect(try Data(contentsOf: url) == original)
    }

    @Test("Fresh Claude profile: short D-pad right sends Return, long sends Command-Return only")
    func claudeDpadRightReplay() {
        let support = temporarySupport()
        let store = UnifiedProfileStore(applicationSupport: support)
        let replay = MappingReplay(target: .claudeCode, profile: store.load(for: .claudeCode).profile, preview: false)
        replay.tap(.dpadRight, 0)
        _ = replay.edge(.dpadRight, .pressed, 1)
        replay.advance(2.90)
        #expect(replay.output == [.key(36, [], .tap)])
        replay.advance(3.10)
        _ = replay.edge(.dpadRight, .released, 3.20)
        replay.advance(4)
        #expect(replay.output == [.key(36, [], .tap), .key(36, [.command], .tap)])
        #expect(!FileManager.default.fileExists(atPath: support.path))
    }

    private func temporarySupport() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("joyrelay-replay-\(UUID())")
    }
}

private enum ReplayOutput: Equatable {
    case key(UInt16, Set<KeyModifier>, ShortcutEmissionPhase)
    case scroll(ScrollCommand)
    case desktop(DesktopUIAction)
}

private final class MappingReplay: DesktopUIActionEmitting {
    private(set) var session: UnifiedControllerSession
    private(set) var output: [ReplayOutput] = []
    private let profile: MappingProfile
    private let preview: Bool
    private let origin = Date(timeIntervalSince1970: 10_000)

    init(target: DesktopTarget, profile: MappingProfile, preview: Bool) {
        session = UnifiedControllerSession(target: target)
        self.profile = profile
        self.preview = preview
    }

    func edge(_ input: ControllerInput, _ phase: InputPhase, _ time: Double,
              layout: ControllerEventLayout? = nil) -> UnifiedSessionResult {
        session.process(ControllerEvent(input: input, phase: phase,
            timestamp: origin.addingTimeInterval(time), layout: layout),
            profile: profile, testMode: preview, emitter: self)
    }

    func tap(_ input: ControllerInput, _ time: Double, layout: ControllerEventLayout? = nil) {
        _ = edge(input, .pressed, time, layout: layout)
        _ = edge(input, .released, time + 0.05, layout: layout)
    }

    func advance(_ time: Double) {
        _ = session.advance(to: origin.addingTimeInterval(time), testMode: preview, emitter: self)
    }

    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws {
        output.append(.key(shortcut.keyCode, shortcut.modifiers, phase))
    }

    func emit(_ command: ScrollCommand) throws { output.append(.scroll(command)) }

    func emit(_ action: DesktopUIAction) throws { output.append(.desktop(action)) }
}
