import Foundation
import GameController
import JoyConCodexCore

/// Exercises the handlers installed by the real adapter on a connected Pro.
/// There is intentionally no AppModel or emitter: no shortcuts, app activation,
/// permissions requests, or reads/writes of the user's mapping profiles.
@main
struct SwitchProAdapterProbe {
    @MainActor
    static func main() async {
        GCController.shouldMonitorBackgroundEvents = true
        let clock = ContinuousClock()
        let discoveryDeadline = clock.now.advanced(by: .seconds(4))
        var controllers = GCController.controllers()
        while controllers.isEmpty && clock.now < discoveryDeadline {
            try? await clock.sleep(for: .milliseconds(50))
            controllers = GCController.controllers()
        }
        guard controllers.count == 1, let pro = controllers.first,
              pro.productCategory == "Switch Pro Controller", let pad = pro.extendedGamepad else {
            let found = controllers.map(\.productCategory).joined(separator: ", ")
            fail("NOT RUN: connect one Switch Pro Controller and disconnect other controllers (found: \(found.isEmpty ? "none" : found)).", code: 2)
        }

        let adapter = GameControllerAdapter()
        guard adapter.descriptors.count == 1,
              adapter.descriptors.first(where: \.isSupported)?.side == .switchPro else {
            fail("NOT RUN: the connected Switch Pro is not the adapter's active controller.", code: 2)
        }
        var received: [Edge] = []
        adapter.onEvent = { received.append(Edge($0.input, $0.phase, $0.layout)) }
        var expected: [Edge] = []

        func inject(_ edge: Edge, using handler: () -> Void) async {
            expected.append(edge)
            handler()
            let deadline = clock.now.advanced(by: .seconds(1))
            while received.count < expected.count && clock.now < deadline {
                try? await clock.sleep(for: .milliseconds(5))
            }
            compare(expected: expected, received: received)
        }

        let rightHand = ControllerEventLayout.switchProRightHand
        let buttons: [(String, GCControllerButtonInput?, ControllerInput, ControllerEventLayout?)] = [
            ("R", pad.rightShoulder, .rightShoulder, rightHand),
            ("ZR", pad.rightTrigger, .rightTrigger, rightHand),
            ("R3", pad.rightThumbstickButton, .rightStickPress, rightHand),
            ("L", pad.leftShoulder, .leftShoulder, nil),
            ("ZL", pad.leftTrigger, .leftTrigger, nil),
            ("L3", pad.leftThumbstickButton, .leftStickPress, nil),
            ("Capture", pro.physicalInputProfile.buttons[GCInputButtonShare], .buttonCapture, nil),
            ("D-pad up", pad.dpad.up, .dpadUp, nil),
            ("D-pad down", pad.dpad.down, .dpadDown, nil),
            ("D-pad left", pad.dpad.left, .dpadLeft, nil),
            ("D-pad right", pad.dpad.right, .dpadRight, nil),
        ]
        for (name, button, input, layout) in buttons {
            guard let button, let handler = button.pressedChangedHandler else {
                fail("FAIL: missing \(name) input or adapter callback.")
            }
            await inject(Edge(input, .pressed, layout)) { handler(button, 1, true) }
            await inject(Edge(input, .released, layout)) { handler(button, 0, false) }
        }

        let sticks: [(String, GCControllerDirectionPad, [ControllerInput], ControllerEventLayout?)] = [
            ("right", pad.rightThumbstick, [.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight], rightHand),
            ("left", pad.leftThumbstick, [.leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight], nil),
        ]
        let vectors: [(Float, Float)] = [(0, 1), (0, -1), (-1, 0), (1, 0)]
        for (name, stick, inputs, layout) in sticks {
            guard let handler = stick.valueChangedHandler else {
                fail("FAIL: missing \(name) stick adapter callback.")
            }
            for (input, (x, y)) in zip(inputs, vectors) {
                await inject(Edge(input, .pressed, layout)) { handler(stick, x, y) }
                await inject(Edge(input, .released, layout)) { handler(stick, 0, 0) }
            }
        }

        // Give any extra queued edges a chance to surface after the last release.
        try? await clock.sleep(for: .milliseconds(100))
        compare(expected: expected, received: received)
        for edge in received { print(edge) }
        print("PASS: \(received.count) ordered Switch Pro adapter events; no desktop output.")
    }

    private struct Edge: Equatable, CustomStringConvertible {
        let input: ControllerInput
        let phase: InputPhase
        let layout: ControllerEventLayout?

        init(_ input: ControllerInput, _ phase: InputPhase, _ layout: ControllerEventLayout?) {
            self.input = input
            self.phase = phase
            self.layout = layout
        }

        var description: String { "\(input.rawValue):\(phase.rawValue):\(layout?.rawValue ?? "shared")" }
    }

    private static func compare(expected: [Edge], received: [Edge]) {
        guard expected != received else { return }
        for index in 0..<max(expected.count, received.count) {
            let want = index < expected.count ? expected[index].description : "<none>"
            let got = index < received.count ? received[index].description : "<none>"
            if want != got { fail("FAIL: edge \(index + 1): expected \(want); got \(got).") }
        }
    }

    private static func fail(_ message: String, code: Int32 = 1) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(code)
    }
}
