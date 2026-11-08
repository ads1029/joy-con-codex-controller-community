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

    private func fullReport(left: UInt8 = 0, shared: UInt8 = 0, id: UInt8 = 0x30) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 49)
        bytes[0] = id; bytes[1] = 0x3d; bytes[2] = 0x4e
        bytes[4] = shared; bytes[5] = left
        return bytes
    }

    private func report(_ state: inout LeftJoyConSupplementState, id: UInt32 = 0x30,
        bytes: [UInt8]) throws -> [ControllerEvent] {
        let result = state.processReport(reportID: id, bytes: bytes)
        return try #require(result)
    }

    @Test("Captured full-report L and ZL edges work without any HID element callback")
    func reportOnlyTopButtons() throws {
        var state = LeftJoyConSupplementState()
        var events: [ControllerEvent] = []
        for left: UInt8 in [0, 0x40, 0, 0x80, 0] {
            events += try report(&state, bytes: fullReport(left: left))
        }
        #expect(events.map(\.input) == [.leftShoulder, .leftShoulder, .leftTrigger, .leftTrigger])
        #expect(events.map(\.phase) == [.pressed, .released, .pressed, .released])
        #expect(state.held.isEmpty && state.usesReportInput)
    }

    @Test("Report and element sources cannot double-press or prematurely release a report-held L")
    func reportAndValueDeduplication() throws {
        var state = LeftJoyConSupplementState()
        #expect(state.processUsage(15, value: 1).map(\.phase) == [.pressed])
        #expect(try report(&state, bytes: fullReport(left: 0x40)).isEmpty)
        #expect(state.processUsage(15, value: 0).isEmpty)
        #expect(state.held == [.leftShoulder])
        #expect(try report(&state, bytes: fullReport()).map(\.phase) == [.released])
        #expect(state.processUsage(15, value: 0).isEmpty)
    }

    @Test("Full reports keep Fn before L3 and release Fn last; command replies cannot cancel a hold")
    func fullReportFunctionLayer() throws {
        var state = LeftJoyConSupplementState()
        var engine = MappingEngine()
        let recorder = L3Recorder()
        let down = try report(&state, bytes: fullReport(left: 0x80, shared: 0x08))
        #expect(down.map(\.input) == [.leftTrigger, .leftStickPress])
        for event in down { _ = engine.process(event, profile: l3Profile(), testMode: false, emitter: recorder) }
        #expect(state.processReport(reportID: 0x21, bytes: fullReport(id: 0x21)) == nil)
        #expect(state.held == [.leftTrigger, .leftStickPress])
        let up = try report(&state, bytes: fullReport())
        #expect(up.map(\.input) == [.leftStickPress, .leftTrigger])
        for event in up { _ = engine.process(event, profile: l3Profile(), testMode: false, emitter: recorder) }
        #expect(recorder.shortcuts == [Shortcut(keyCode: 18, displayLabel: "1", modifiers: [.command])])
        #expect(!engine.isFunctionLayerActive)
    }

    @Test("Simple and full report mode changes share one held state and ignore GameController-owned controls")
    func reportModes() throws {
        var state = LeftJoyConSupplementState()
        let first = try report(&state, bytes: fullReport(left: 0x7f))
        #expect(first.map(\.input) == [.leftShoulder]) // other left-bank bits belong to GC
        var simple = [UInt8](repeating: 0, count: 12); simple[0] = 0x3f; simple[2] = 0x40
        #expect(try report(&state, id: 0x3f, bytes: simple).isEmpty)
        simple[2] = 0x04
        let changed = try report(&state, id: 0x3f, bytes: simple)
        #expect(changed.map(\.input) == [.leftShoulder, .leftStickPress])
        #expect(changed.map(\.phase) == [.released, .pressed])
        #expect(state.reset().map(\.phase) == [.released])
        #expect(!state.usesReportInput && state.held.isEmpty)
        #expect(state.processUsage(16, value: 1).map(\.input) == [.leftTrigger])
    }

    @Test("Explicit headerless frames are unambiguous even when the timer equals the report ID")
    func reportValidation() {
        var bytes = fullReport(left: 0xc0, shared: 0x08); bytes[1] = 0x30
        #expect(LeftJoyConHIDMapping.inputs(reportID: 0x30, bytes: bytes) == [.leftShoulder, .leftTrigger, .leftStickPress])
        #expect(LeftJoyConHIDMapping.inputs(reportID: 0x30, bytes: Array(bytes.dropFirst()),
            includesReportID: false) == [.leftShoulder, .leftTrigger, .leftStickPress])
        for id: UInt32 in [0x21, 0x23, 0x81, 0x100] {
            #expect(LeftJoyConHIDMapping.inputs(reportID: id, bytes: bytes) == nil)
        }
        #expect(LeftJoyConHIDMapping.inputs(reportID: 0x30, bytes: Array(bytes.prefix(6))) == nil)
        #expect(LeftJoyConHIDMapping.inputs(reportID: 0x31, bytes: bytes) == nil)
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
