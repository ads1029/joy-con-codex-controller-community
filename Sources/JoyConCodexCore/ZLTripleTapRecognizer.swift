import Foundation

/// Counts complete, unchorded ZL taps without delaying the function layer.
struct ZLTripleTapRecognizer: Sendable {
    static let maximumHold: TimeInterval = 0.300
    static let maximumGap: TimeInterval = 0.350
    static let maximumSequence: TimeInterval = 1.000

    private var pressedAt: Date?
    private var firstPressedAt: Date?
    private var lastReleasedAt: Date?
    private var count = 0

    mutating func reset() { self = Self() }

    mutating func process(_ event: ControllerEvent, freshPress: Bool,
        otherControlsHeld: Bool) -> Bool {
        guard event.input == .leftTrigger, !otherControlsHeld else {
            reset()
            return false
        }
        switch event.phase {
        case .pressed:
            guard freshPress else { return false }
            if let lastReleasedAt {
                let gap = event.timestamp.timeIntervalSince(lastReleasedAt)
                if gap < 0 || gap > Self.maximumGap { reset() }
            }
            if firstPressedAt == nil { firstPressedAt = event.timestamp }
            pressedAt = event.timestamp
        case .released:
            guard let pressedAt, let firstPressedAt else { return false }
            let hold = event.timestamp.timeIntervalSince(pressedAt)
            let sequence = event.timestamp.timeIntervalSince(firstPressedAt)
            guard hold >= 0, hold <= Self.maximumHold,
                  sequence >= 0, sequence <= Self.maximumSequence else {
                reset()
                return false
            }
            self.pressedAt = nil
            lastReleasedAt = event.timestamp
            count += 1
            if count == 3 {
                reset()
                return true
            }
        }
        return false
    }
}
