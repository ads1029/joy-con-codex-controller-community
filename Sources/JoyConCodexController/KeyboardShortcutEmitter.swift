import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import JoyConCodexCore

enum ShortcutEmissionError: LocalizedError {
    case accessibilityPermissionRequired
    case invalidShortcut
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityPermissionRequired:
            "Accessibility permission is required for live output."
        case .invalidShortcut:
            "The resolved shortcut is invalid."
        case .eventCreationFailed:
            "macOS could not create a keyboard event."
        }
    }
}

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = [
            "AXTrustedCheckOptionPrompt": prompt,
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

struct CoreGraphicsShortcutEmitter: ShortcutEmitting {
    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws {
        guard AccessibilityPermission.isTrusted() else {
            throw ShortcutEmissionError.accessibilityPermissionRequired
        }
        guard
            let option = KeyCatalog.option(for: shortcut.keyCode),
            option.label == shortcut.displayLabel
        else {
            throw ShortcutEmissionError.invalidShortcut
        }

        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: true
            ),
            let keyUp = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.keyCode),
                keyDown: false
            )
        else {
            throw ShortcutEmissionError.eventCreationFailed
        }

        let flags = shortcut.modifiers.reduce(into: CGEventFlags()) { result, modifier in
            switch modifier {
            case .command:
                result.insert(.maskCommand)
            case .option:
                result.insert(.maskAlternate)
            case .control:
                result.insert(.maskControl)
            case .shift:
                result.insert(.maskShift)
            }
        }

        keyDown.flags = flags
        keyUp.flags = flags
        switch phase {
        case .tap:
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        case .keyDown:
            keyDown.post(tap: .cghidEventTap)
        case .keyUp:
            keyUp.post(tap: .cghidEventTap)
        }
    }

    func emit(_ scrollCommand: ScrollCommand) throws {
        guard AccessibilityPermission.isTrusted() else {
            throw ShortcutEmissionError.accessibilityPermissionRequired
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let delta: Int32
        switch scrollCommand {
        case .up:
            delta = 5
        case .down:
            delta = -5
        case .toBottom:
            delta = -10_000
        }
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else {
            throw ShortcutEmissionError.eventCreationFailed
        }
        if let target = frontmostWindowScrollPoint() {
            event.location = target
        }
        event.post(tap: .cghidEventTap)
    }

    private func frontmostWindowScrollPoint() -> CGPoint? {
        let codexBundleIdentifier = "com.openai.codex"
        let targetApplication = NSRunningApplication.runningApplications(
            withBundleIdentifier: codexBundleIdentifier
        ).first ?? NSWorkspace.shared.frontmostApplication
        guard let targetApplication else {
            return nil
        }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier
            != targetApplication.processIdentifier
        {
            _ = targetApplication.activate(options: [])
            Thread.sleep(forTimeInterval: 0.08)
        }
        let processIdentifier = targetApplication.processIdentifier
        guard
            let windowInfo = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }
        let bounds = windowInfo.compactMap { info -> CGRect? in
            guard
                (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == processIdentifier,
                (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                let dictionary = info[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                bounds.width > 300,
                bounds.height > 300
            else {
                return nil
            }
            return bounds
        }
        guard let window = bounds.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            return nil
        }
        return CGPoint(x: window.midX, y: window.minY + window.height * 0.42)
    }
}
