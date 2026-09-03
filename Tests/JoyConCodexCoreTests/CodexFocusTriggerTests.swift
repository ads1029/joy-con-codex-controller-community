import Foundation
import JoyConCodexCore
import Testing

@Suite("Codex focus trigger")
struct CodexFocusTriggerTests {
    @Test("Every stick direction press requests focus")
    func stickDirectionPresses() {
        let stickDirections: [ControllerInput] = [
            .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
            .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight,
        ]

        for input in stickDirections {
            let event = ControllerEvent(input: input, phase: .pressed)
            #expect(CodexFocusTrigger.shouldFocus(for: event))
        }
    }

    @Test("Stick releases do not request focus")
    func stickRelease() {
        let event = ControllerEvent(input: .rightStickUp, phase: .released)
        #expect(!CodexFocusTrigger.shouldFocus(for: event))
    }

    @Test("Stick-button presses are ordinary buttons")
    func stickButton() {
        let event = ControllerEvent(input: .rightStickPress, phase: .pressed)
        #expect(!CodexFocusTrigger.shouldFocus(for: event))
    }

    @Test("Non-stick controls do not request focus", arguments: ControllerInput.allCases)
    func otherControls(input: ControllerInput) {
        guard !input.isStickDirection else { return }
        let event = ControllerEvent(input: input, phase: .pressed)
        #expect(!CodexFocusTrigger.shouldFocus(for: event))
    }
}
