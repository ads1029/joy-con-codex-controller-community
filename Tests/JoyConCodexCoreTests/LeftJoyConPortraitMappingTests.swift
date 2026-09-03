import Testing
@testable import JoyConCodexCore

@Suite("Left Joy-Con portrait adapter")
struct LeftJoyConPortraitMappingTests {
    @Test("Horizontal face labels become the hardware-verified vertical D-pad directions")
    func faceButtonTranslation() {
        #expect(LeftJoyConPortraitMapping.input(for: .buttonX) == .dpadDown)
        #expect(LeftJoyConPortraitMapping.input(for: .buttonB) == .dpadUp)
        #expect(LeftJoyConPortraitMapping.input(for: .buttonA) == .dpadLeft)
        #expect(LeftJoyConPortraitMapping.input(for: .buttonY) == .dpadRight)
    }

    @Test("System labels and micro shoulders become physical left controls")
    func auxiliaryButtonTranslation() {
        #expect(LeftJoyConPortraitMapping.input(for: .buttonMenu) == .buttonMinus)
        #expect(LeftJoyConPortraitMapping.input(for: .buttonHome) == .buttonCapture)
        #expect(LeftJoyConPortraitMapping.input(for: .leftShoulder) == .buttonSL)
        #expect(LeftJoyConPortraitMapping.input(for: .rightShoulder) == .buttonSR)
    }

    @Test("Portrait axes match the hardware-verified visual directions")
    func portraitAxisRotation() {
        #expect(
            LeftJoyConPortraitMapping.transform(x: 1, y: 0, orientation: .portrait)
                == JoyConVector(x: 0, y: -1)
        )
        #expect(
            LeftJoyConPortraitMapping.transform(x: 0, y: 1, orientation: .portrait)
                == JoyConVector(x: 1, y: 0)
        )
        #expect(
            LeftJoyConPortraitMapping.transform(x: -1, y: 0, orientation: .portrait)
                == JoyConVector(x: 0, y: 1)
        )
        #expect(
            LeftJoyConPortraitMapping.transform(x: 0, y: -1, orientation: .portrait)
                == JoyConVector(x: -1, y: 0)
        )
    }

    @Test("Sideways mode preserves the GameController axes")
    func sidewaysAxes() {
        #expect(
            LeftJoyConPortraitMapping.transform(x: 0.25, y: -0.75, orientation: .sideways)
                == JoyConVector(x: 0.25, y: -0.75)
        )
    }
}
