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

final class CoreGraphicsShortcutEmitter: HeldShortcutRecovering, DesktopUIActionEmitting {
    var target: DesktopTarget = .codex
    let driver = DesktopApplicationDriver()
    private(set) var lastScrollDiagnostics = ""
    private var heldDestinations: [Shortcut: pid_t] = [:]
    private var nativeDictation: [Shortcut: DesktopApplicationDriver.DictationControl] = [:]

    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws {
        guard AccessibilityPermission.isTrusted() else {
            throw ShortcutEmissionError.accessibilityPermissionRequired
        }
        if phase == .keyUp {
            if let control = nativeDictation[shortcut] {
                try postDictation(control, down: false)
                nativeDictation.removeValue(forKey: shortcut)
                driver.restorePrompt(after: control)
                return
            }
            guard let pid = heldDestinations[shortcut] else { return }
            try post(shortcut, phase: .keyUp, pid: pid)
            heldDestinations.removeValue(forKey: shortcut)
            return
        }
        try requireExclusiveController()
        let application = try driver.requireDestination(target)
        if target == .claudeCode, phase == .keyDown,
           shortcut.keyCode == 2, shortcut.modifiers == [.control, .shift] {
            let control = try driver.dictationControl()
            try postDictation(control, down: true)
            nativeDictation[shortcut] = control
            return
        }
        switch DesktopShortcutResolver.resolve(shortcut, for: target) {
        case .keyboard(let output):
            try post(output, phase: phase, pid: application.processIdentifier)
            if phase == .keyDown { heldDestinations[shortcut] = application.processIdentifier }
        case .interface(let action):
            guard phase == .tap else { throw ShortcutEmissionError.invalidShortcut }
            try emit(action)
        }
    }

    func emit(_ action: DesktopUIAction) throws {
        try requireExclusiveController()
        _ = try driver.requireDestination(target)
        guard target == .claudeCode else {
            throw DesktopControlError.unavailable("This desktop action requires Claude Code.")
        }
        switch action {
        case .focusPrompt(let side):
            guard nativeDictation.isEmpty, heldDestinations.isEmpty else {
                throw DesktopControlError.unavailable("Release recording and held shortcuts before changing inputs.")
            }
            try driver.focusPrompt(side)
        case .adjustEffort(let increase):
            try driver.adjustEffort(increase: increase, target: target) { [self] key in
                let current = try driver.requireDestination(target)
                try post(key, phase: .tap, pid: current.processIdentifier)
            }
        }
    }

    func emit(_ scrollCommand: ScrollCommand) throws {
        try requireExclusiveController()
        lastScrollDiagnostics = ""
        let point = try driver.conversationPoint(for: target)
        let delta: Int32 = switch scrollCommand {
        case .up: 5
        case .down: -5
        case .toBottom: -10_000
        }
        guard let event = CGEvent(scrollWheelEvent2Source: CGEventSource(stateID: .hidSystemState),
            units: .line, wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0) else {
            throw ShortcutEmissionError.eventCreationFailed
        }
        event.location = point
        let inheritedFlags = event.flags.rawValue
        // Scrolling is an unmodified controller action, independent of any
        // modifier state inherited from a previous keyboard shortcut.
        event.flags = []
        let destination = try driver.requireDestination(target)
        if target == .codex {
            lastScrollDiagnostics = driver.lastChatGPTScrollGeometry
                + "; flags=\(inheritedFlags)→\(event.flags.rawValue); "
                + driver.scrollHitRoles(at: point, application: destination)
        }
        event.post(tap: .cghidEventTap)
    }

    func releaseHeldKeys() throws {
        var firstError: Error?
        for (shortcut, control) in nativeDictation {
            do {
                try postDictation(control, down: false)
                nativeDictation.removeValue(forKey: shortcut)
                driver.restorePrompt(after: control)
            } catch { if firstError == nil { firstError = error } }
        }
        for (shortcut, pid) in heldDestinations {
            do { try post(shortcut, phase: .keyUp, pid: pid); heldDestinations.removeValue(forKey: shortcut) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }

    private func postDictation(_ control: DesktopApplicationDriver.DictationControl, down: Bool) throws {
        guard AccessibilityPermission.isTrusted() else { throw ShortcutEmissionError.accessibilityPermissionRequired }
        guard let event = CGEvent(mouseEventSource: CGEventSource(stateID: .hidSystemState),
            mouseType: down ? .leftMouseDown : .leftMouseUp, mouseCursorPosition: control.point,
            mouseButton: .left) else { throw ShortcutEmissionError.eventCreationFailed }
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == control.pid {
            if down { _ = try driver.requireDestination(.claudeCode) }
            event.post(tap: .cghidEventTap)
        } else if !down { event.postToPid(control.pid) }
        else { throw DesktopControlError.unavailable("Claude lost focus before recording started.") }
    }

    func requireExclusiveController() throws {
        let legacyIDs = ["com.jinjiang.JoyConCodexController", "com.ads1029.JoyConCodexControllerCommunity"]
        if let conflict = NSWorkspace.shared.runningApplications.first(where: {
            legacyIDs.contains($0.bundleIdentifier ?? "")
                || ($0.localizedName ?? "").localizedCaseInsensitiveContains("Berrry Joyful")
                || ($0.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    && ($0.bundleIdentifier == "com.ads1029.JoyConUnifiedController"
                        || $0.executableURL?.lastPathComponent == "JoyConUnifiedController"))
        }) {
            throw DesktopControlError.unavailable("Quit \(conflict.localizedName ?? "the other controller") before enabling unified output.")
        }
    }

    private func post(_ shortcut: Shortcut, phase: ShortcutEmissionPhase, pid: pid_t) throws {
        guard KeyCatalog.option(for: shortcut.keyCode)?.label == shortcut.displayLabel else {
            throw ShortcutEmissionError.invalidShortcut
        }
        let flags = shortcut.modifiers.reduce(into: CGEventFlags()) { result, modifier in
            switch modifier {
            case .command: result.insert(.maskCommand)
            case .option: result.insert(.maskAlternate)
            case .control: result.insert(.maskControl)
            case .shift: result.insert(.maskShift)
            }
        }
        let phases: [Bool] = phase == .tap ? [true, false] : [phase == .keyDown]
        for keyDown in phases {
            guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState),
                virtualKey: CGKeyCode(shortcut.keyCode), keyDown: keyDown) else {
                throw ShortcutEmissionError.eventCreationFailed
            }
            event.flags = flags
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                event.post(tap: .cghidEventTap)
            } else if !keyDown {
                // Release an old hold to its original destination, never a newly focused app.
                event.postToPid(pid)
            } else {
                throw DesktopControlError.unavailable("The target changed before keyboard output.")
            }
        }
    }
}
