import Testing
@testable import JoyConCodexCore

@Suite("Left Joy-Con HID supplement")
struct LeftJoyConHIDMappingTests {
    @Test("Raw usage 11 is the missing left stick click; right stick stays ignored")
    func stickClick() {
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 11) == .leftStickPress)
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 12) == nil)
    }

    @Test("Raw L3 press release reaches the primary mapping without repeats")
    func rawPrimaryRoute() throws {
        let input = try #require(LeftJoyConHIDMapping.input(forButtonUsage: 11))
        var engine = MappingEngine()
        let recorder = L3Recorder()
        let profile = l3Profile()
        let first = engine.process(.init(input: input, phase: .pressed), profile: profile, testMode: false, emitter: recorder)
        #expect(first.disposition == .emitted)
        let repeatResult = engine.process(.init(input: input, phase: .pressed), profile: profile, testMode: false, emitter: recorder)
        #expect(repeatResult.disposition == .repeated)
        _ = engine.process(.init(input: input, phase: .released), profile: profile, testMode: false, emitter: recorder)
        _ = engine.process(.init(input: input, phase: .pressed), profile: profile, testMode: false, emitter: recorder)
        #expect(recorder.scrolls == [.toBottom, .toBottom])
        #expect(recorder.shortcuts.isEmpty)
    }

    @Test("Raw ZL plus raw L3 selects Command 1 and releases back to primary")
    func rawFunctionRoute() throws {
        let zl = try #require(LeftJoyConHIDMapping.input(forButtonUsage: 16))
        let l3 = try #require(LeftJoyConHIDMapping.input(forButtonUsage: 11))
        var engine = MappingEngine()
        let recorder = L3Recorder()
        let profile = l3Profile()
        for event in [ControllerEvent(input: zl, phase: .pressed), .init(input: l3, phase: .pressed), .init(input: l3, phase: .released), .init(input: zl, phase: .released)] {
            _ = engine.process(event, profile: profile, testMode: false, emitter: recorder)
        }
        #expect(recorder.shortcuts == [Shortcut(keyCode: 18, displayLabel: "1", modifiers: [.command])])
        #expect(recorder.scrolls.isEmpty)
        #expect(!engine.isFunctionLayerActive)
        _ = engine.process(.init(input: l3, phase: .pressed), profile: profile, testMode: false, emitter: recorder)
        #expect(recorder.scrolls == [.toBottom])
    }

    @Test("Raw L3 resolves but emits nothing in Test Mode")
    func rawTestMode() throws {
        let input = try #require(LeftJoyConHIDMapping.input(forButtonUsage: 11))
        var engine = MappingEngine()
        let recorder = L3Recorder()
        let result = engine.process(.init(input: input, phase: .pressed), profile: l3Profile(), testMode: true, emitter: recorder)
        #expect(result.disposition == .suppressedByTestMode)
        #expect(recorder.shortcuts.isEmpty && recorder.scrolls.isEmpty)
    }

    private func l3Profile() -> MappingProfile {
        var profile = MappingProfile.starter
        profile.update(InputMapping(input: .leftStickPress, primaryAction: .scrollToBottom, functionAction: .tap(Shortcut(keyCode: 18, displayLabel: "1", modifiers: [.command]))))
        return profile
    }

    @Test("Raw top button usages become L and ZL")
    func topButtons() {
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 15) == .leftShoulder)
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 16) == .leftTrigger)
    }

    @Test("Raw rail duplicates stay on the GameController path")
    func railDuplicates() {
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 5) == nil)
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 6) == nil)
        #expect(LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(5))
        #expect(LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(6))
        #expect(!LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(15))
    }

    @Test("Other GameController-owned and unknown usages stay out of the HID supplement")
    func ignoresOtherUsages() {
        for usage in [UInt32(1), 2, 3, 4, 7, 8, 9, 10, 99] {
            #expect(LeftJoyConHIDMapping.input(forButtonUsage: usage) == nil)
        }
    }
}

private final class L3Recorder: ShortcutEmitting {
    var shortcuts: [Shortcut] = []
    var scrolls: [ScrollCommand] = []
    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws { shortcuts.append(shortcut) }
    func emit(_ command: ScrollCommand) throws { scrolls.append(command) }
}
