public enum CodexFocusTrigger {
    public static func shouldFocus(for event: ControllerEvent) -> Bool {
        event.phase == .pressed && event.input.isStickDirection
    }
}

public extension ControllerInput {
    var isStickDirection: Bool {
        switch self {
        case .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
             .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight:
            true
        default:
            false
        }
    }
}
