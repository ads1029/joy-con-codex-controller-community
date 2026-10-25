import Foundation

/// Electron can initially expose only its native window shell. Do not inspect
/// page controls until the web accessibility tree has appeared.
@MainActor
public enum DesktopAccessibilityReadiness {
    public static func prepare(attempts: Int = 20, enable: () -> Void,
                               isReady: () -> Bool,
                               pause: () async throws -> Void) async throws -> Bool {
        try Task.checkCancellation()
        enable()
        for attempt in 0..<max(1, attempts) {
            try Task.checkCancellation()
            if isReady() { return true }
            if attempt + 1 < attempts { try await pause() }
        }
        return false
    }
}
