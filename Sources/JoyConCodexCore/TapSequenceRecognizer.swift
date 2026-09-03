import Foundation

public enum TapSequencePressDisposition: Equatable, Sendable {
    case firstTap
    case secondTap
    case repeated
}

public enum TapSequenceReleaseDisposition: Equatable, Sendable {
    case singlePending(deadline: Date)
    case doubleTap
    case ignored
}

/// Resolves press/release edges without owning a clock or timer. The app schedules
/// the delayed single-tap action and calls `expire` when its deadline arrives.
public struct TapSequenceRecognizer: Sendable {
    private var pressedInputs = Set<ControllerInput>()
    private var pendingDeadlines: [ControllerInput: Date] = [:]
    private var secondTapInputs = Set<ControllerInput>()

    public init() {}

    public mutating func press(
        _ input: ControllerInput,
        at timestamp: Date
    ) -> TapSequencePressDisposition {
        guard pressedInputs.insert(input).inserted else { return .repeated }
        if let deadline = pendingDeadlines[input], timestamp <= deadline {
            pendingDeadlines.removeValue(forKey: input)
            secondTapInputs.insert(input)
            return .secondTap
        }
        return .firstTap
    }

    public mutating func release(
        _ input: ControllerInput,
        at timestamp: Date,
        intervalMilliseconds: Int
    ) -> TapSequenceReleaseDisposition {
        guard pressedInputs.remove(input) != nil else { return .ignored }
        if secondTapInputs.remove(input) != nil {
            return .doubleTap
        }
        let deadline = timestamp.addingTimeInterval(Double(intervalMilliseconds) / 1_000)
        pendingDeadlines[input] = deadline
        return .singlePending(deadline: deadline)
    }

    @discardableResult
    public mutating func expire(_ input: ControllerInput, at timestamp: Date) -> Bool {
        guard let deadline = pendingDeadlines[input], deadline <= timestamp else { return false }
        pendingDeadlines.removeValue(forKey: input)
        return true
    }

    public mutating func cancel(_ input: ControllerInput) {
        pressedInputs.remove(input)
        pendingDeadlines.removeValue(forKey: input)
        secondTapInputs.remove(input)
    }

    public mutating func reset() {
        pressedInputs.removeAll()
        pendingDeadlines.removeAll()
        secondTapInputs.removeAll()
    }
}
