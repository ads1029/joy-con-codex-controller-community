public enum SingleJoyConOrientation: String, CaseIterable, Codable, Sendable, Identifiable {
    case portrait
    case sideways

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .portrait: "Portrait — Minus at top"
        case .sideways: "Sideways — rail at top"
        }
    }
}

public enum LeftJoyConPhysicalButton: String, CaseIterable, Sendable {
    case buttonA = "Button A"
    case buttonB = "Button B"
    case buttonX = "Button X"
    case buttonY = "Button Y"
    case buttonMenu = "Button Menu"
    case buttonHome = "Button Home"
    case leftShoulder = "Left Shoulder"
    case rightShoulder = "Right Shoulder"
}

public struct JoyConVector: Equatable, Sendable {
    public let x: Float
    public let y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public enum LeftJoyConPortraitMapping {
    /// Apple exposes a single left Joy-Con as a horizontal micro gamepad.
    /// These labels translate that generic profile back to the symbols printed
    /// on a left Joy-Con held vertically with Minus at the top.
    public static func input(for button: LeftJoyConPhysicalButton) -> ControllerInput {
        switch button {
        // Hardware verification on the vertically held left Joy-Con shows
        // Apple's X/B labels are inverted relative to the printed up/down
        // directions.
        case .buttonX: .dpadDown
        case .buttonB: .dpadUp
        case .buttonA: .dpadLeft
        case .buttonY: .dpadRight
        case .buttonMenu: .buttonMinus
        case .buttonHome: .buttonCapture
        // Hardware verification shows Apple's two micro-gamepad shoulder
        // fields are the rail buttons, not the top L/ZL buttons.
        case .leftShoulder: .buttonSL
        case .rightShoulder: .buttonSR
        }
    }

    /// In portrait mode the horizontal micro-gamepad axes are rotated back
    /// into the user's visual coordinate system. Sideways preserves Apple's
    /// reported coordinate system.
    public static func transform(
        x: Float,
        y: Float,
        orientation: SingleJoyConOrientation
    ) -> JoyConVector {
        switch orientation {
        case .portrait:
            // Hardware verification on the user's vertically held left
            // Joy-Con showed both output directions reversed. Negating the
            // previous portrait vector preserves the 90-degree rotation while
            // aligning up/down and left/right with the physical stick.
            JoyConVector(x: y, y: -x)
        case .sideways:
            JoyConVector(x: x, y: y)
        }
    }
}
