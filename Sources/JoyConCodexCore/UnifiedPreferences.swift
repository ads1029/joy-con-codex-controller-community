import Foundation

public enum UnifiedPreferences {
    public static let domain = "com.ads1029.JoyConUnifiedController"

    public static func make(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> UserDefaults? {
        // Foundation explicitly forbids passing the main bundle ID as a suite.
        // Bundled runs use their own standard domain. CLI runs use a named suite;
        // failure is represented by nil, never a fallback to the host's domain.
        if bundleIdentifier == domain { return .standard }
        return UserDefaults(suiteName: domain)
    }
}
