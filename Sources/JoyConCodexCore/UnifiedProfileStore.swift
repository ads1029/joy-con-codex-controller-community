import Foundation

public struct UnifiedProfileStore: Sendable {
    public static let directoryName = "JoyConUnifiedController"
    public let directory: URL
    public let legacyProfileURL: URL

    public init(applicationSupport: URL) {
        directory = applicationSupport.appendingPathComponent(Self.directoryName, isDirectory: true)
        legacyProfileURL = applicationSupport.appendingPathComponent("JoyConCodexController", isDirectory: true)
            .appendingPathComponent("mapping-profile.json")
    }

    public func store(for target: DesktopTarget) -> ProfileStore {
        ProfileStore(profileURL: directory.appendingPathComponent("\(target.rawValue)-profile.json"))
    }

    public func load(for target: DesktopTarget) -> ProfileLoadResult {
        let destination = store(for: target)
        if FileManager.default.fileExists(atPath: destination.profileURL.path) {
            let result = destination.load()
            if let message = result.recoveryMessage {
                return .recovered(reservedControlsDisabled(result.profile), message: message)
            }
            return .loaded(reservedControlsDisabled(result.profile))
        }
        // Read only: neither the old profile nor a new profile is saved on launch.
        do {
            if FileManager.default.fileExists(atPath: legacyProfileURL.path) {
                let data = try Data(contentsOf: legacyProfileURL)
                return .defaults(adaptImportedBaseline(try destination.decode(data), for: target))
            }
            return .defaults(adaptImportedBaseline(.starter, for: target))
        } catch {
            return .recovered(adaptImportedBaseline(.starter, for: target),
                message: "Legacy profile was left untouched: \(error.localizedDescription)")
        }
    }

    public func save(_ profile: MappingProfile, for target: DesktopTarget) throws {
        try store(for: target).save(reservedControlsDisabled(profile))
    }

    /// Upgrade only known imported bindings at their established controls.
    /// Saved per-target profiles and arbitrary user shortcuts remain authoritative.
    public func adaptImportedBaseline(_ profile: MappingProfile, for target: DesktopTarget) -> MappingProfile {
        var result = reservedControlsDisabled(profile)
        guard target == .codex else {
            // Hold D-pad right to send ⌘Return when it is still the plain Enter key.
            if var confirm = result.mapping(for: .dpadRight),
               confirm.primaryAction == .tap(Shortcut(keyCode: 36, displayLabel: "Return")),
               confirm.longPressAction == nil {
                confirm.longPressAction = .tap(Shortcut(keyCode: 36, displayLabel: "Return", modifiers: [.command]))
                result.update(confirm)
            }
            return result
        }
        let replacements: [(ControllerInput, Shortcut, Shortcut)] = [
            (.leftStickUp,
             Shortcut(keyCode: 33, displayLabel: "[", modifiers: [.command, .shift]),
             Shortcut(keyCode: 33, displayLabel: "[", modifiers: [.command, .option])),
            (.leftStickDown,
             Shortcut(keyCode: 30, displayLabel: "]", modifiers: [.command, .shift]),
             Shortcut(keyCode: 30, displayLabel: "]", modifiers: [.command, .option])),
            (.dpadLeft,
             Shortcut(keyCode: 11, displayLabel: "B", modifiers: [.command]),
             Shortcut(keyCode: 1, displayLabel: "S", modifiers: [.command, .shift])),
            (.buttonY,
             Shortcut(keyCode: 11, displayLabel: "B", modifiers: [.command]),
             Shortcut(keyCode: 1, displayLabel: "S", modifiers: [.command, .shift])),
            (.dpadRight,
             Shortcut(keyCode: 11, displayLabel: "B", modifiers: [.command, .option]),
             Shortcut(keyCode: 14, displayLabel: "E", modifiers: [.command, .shift])),
            (.buttonA,
             Shortcut(keyCode: 11, displayLabel: "B", modifiers: [.command, .option]),
             Shortcut(keyCode: 14, displayLabel: "E", modifiers: [.command, .shift])),
        ]
        for (input, old, new) in replacements {
            guard var mapping = result.mapping(for: input), mapping.functionAction == .tap(old) else { continue }
            mapping.functionAction = .tap(new)
            result.update(mapping)
        }
        return result
    }

    public func reservedControlsDisabled(_ profile: MappingProfile) -> MappingProfile {
        var result = profile
        for input in [ControllerInput.buttonSL, .buttonSR] {
            result.update(InputMapping(input: input, primaryAction: nil))
        }
        result.update(InputMapping(input: .leftTrigger, primaryAction: .functionLayer))
        if var capture = result.mapping(for: .buttonCapture) {
            capture.functionAction = nil // The former ZL+Capture chord remains disabled.
            result.update(capture)
        }
        return result
    }
}
