import Foundation

public struct DesktopWindowIdentity: Codable, Equatable, Hashable, Sendable {
    public let processID: Int32
    public let windowID: UInt32

    public init(processID: Int32, windowID: UInt32) {
        self.processID = processID
        self.windowID = windowID
    }
}

public enum DesktopWindowMatching {
    public static func resolve(saved: DesktopWindowIdentity?, current: [DesktopWindowIdentity]) -> DesktopWindowIdentity? {
        if let saved {
            if current.contains(saved) { return saved }
            // A closed window must never silently become another window in the
            // same process, even if that is now the only remaining window.
            if current.contains(where: { $0.processID == saved.processID }) { return nil }
        }
        // A restarted app (or old snapshot) can only be matched unambiguously.
        return current.count == 1 ? current[0] : nil
    }
}
