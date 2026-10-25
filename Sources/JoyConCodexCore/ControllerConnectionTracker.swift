import Foundation

/// Battery refreshes and discovery rescans must not repeat connection effects.
public struct ControllerConnectionTracker: Sendable {
    private var connected: Set<String> = []

    public init() {}

    public mutating func update(_ ids: Set<String>) -> Bool {
        let arrived = !ids.subtracting(connected).isEmpty
        connected = ids
        return arrived
    }
}
