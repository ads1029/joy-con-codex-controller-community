import Foundation

public enum ContinuousOutput: Equatable, Sendable {
    case keyboardTap(Shortcut)
    case scroll(ScrollCommand)
}

public struct RepeatPlan: Equatable, Sendable {
    public let initialDelayMilliseconds: UInt64
    public let intervalMilliseconds: UInt64
    public let output: ContinuousOutput

    public init(
        initialDelayMilliseconds: UInt64,
        intervalMilliseconds: UInt64,
        output: ContinuousOutput
    ) {
        self.initialDelayMilliseconds = initialDelayMilliseconds
        self.intervalMilliseconds = intervalMilliseconds
        self.output = output
    }
}

public enum ControllerRepeatPolicy {
    public static func plan(
        for input: ControllerInput,
        action: MappingAction
    ) -> RepeatPlan? {
        if let command = action.scrollCommand, command != .toBottom {
            return RepeatPlan(
                initialDelayMilliseconds: 280,
                intervalMilliseconds: 65,
                output: .scroll(command)
            )
        }

        guard action.kind == .tap, let shortcut = action.shortcut else { return nil }
        let shouldRepeat: Bool
        switch input {
        case .leftStickLeft:
            shouldRepeat = shortcut.keyCode == 123
        case .leftStickRight:
            shouldRepeat = shortcut.keyCode == 124
        case .dpadLeft:
            shouldRepeat = shortcut.keyCode == 51
        default:
            shouldRepeat = false
        }
        guard shouldRepeat else { return nil }
        return RepeatPlan(
            initialDelayMilliseconds: 330,
            intervalMilliseconds: 55,
            output: .keyboardTap(shortcut)
        )
    }
}
