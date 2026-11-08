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
    private(set) var lastVoiceDiagnostic = ""
    private struct NativeCodexHold {
        let input: Shortcut
        let output: Shortcut
        let plan: NativeDictationHoldPlan
        let pid: pid_t
    }
    private var nativeCodexHold: NativeCodexHold?
    private struct CodexHold {
        let shortcut: Shortcut
        var preparation: DesktopApplicationDriver.CodexDictationPreparation
        var control: DesktopApplicationDriver.CodexDictationControl?
        var releaseDeadline: ContinuousClock.Instant?
    }
    private var codexDictation: CodexHold?
    private var nativeDictation: [Shortcut: DesktopApplicationDriver.DictationControl] = [:]
    var isPreparingCodexDictation: Bool {
        codexDictation != nil && codexDictation?.control == nil && codexDictation?.releaseDeadline == nil
    }

    func emit(_ shortcut: Shortcut, phase: ShortcutEmissionPhase) throws {
        guard AccessibilityPermission.isTrusted() else {
            throw ShortcutEmissionError.accessibilityPermissionRequired
        }
        if phase == .keyUp {
            if nativeCodexHold?.input == shortcut {
                try stopCodexNativeDictation()
                return
            }
            if codexDictation?.shortcut == shortcut {
                requestCodexRelease()
                try advanceDictationRelease()
                return
            }
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
        switch DesktopShortcutResolver.resolve(shortcut, for: target, phase: phase) {
        case .dictation:
            guard codexDictation == nil, nativeCodexHold == nil else {
                throw DesktopControlError.unavailable("Wait for the previous dictation to finish.")
            }
            switch target {
            case .codex:
                do {
                    if let output = try configuredCodexDictationShortcut() {
                        try startCodexNativeDictation(input: shortcut, output: output,
                            pid: application.processIdentifier)
                    } else {
                        lastVoiceDiagnostic = "Codex · 未配置可用的原生按住快捷键；尝试 AX 麦克风"
                        let preparation = try driver.prepareCodexDictation(in: application)
                        codexDictation = CodexHold(shortcut: shortcut, preparation: preparation)
                        try advanceDictationRelease()
                    }
                } catch {
                    lastVoiceDiagnostic = "Codex 语音输出被阻止：\(error.localizedDescription)"
                    throw error
                }
            case .claudeCode:
                let control = try driver.dictationControl()
                try postDictation(control, down: true)
                nativeDictation[shortcut] = control
            }
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
            guard nativeDictation.isEmpty, nativeCodexHold == nil, heldDestinations.isEmpty else {
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

    private func requestCodexRelease() {
        if codexDictation?.releaseDeadline == nil {
            codexDictation?.releaseDeadline = .now.advanced(by: .seconds(2))
        }
    }

    func advanceDictationRelease(force: Bool = false) throws {
        guard var hold = codexDictation else { return }
        do {
            if hold.control == nil {
                // Cancellation wins over readiness. A released or disconnected
                // controller must never start recording when AX wakes up later.
                let step = CodexDictationPreparationPolicy.next(
                    isHeld: hold.releaseDeadline == nil, ready: false, timedOut: false)
                if step == .cancel { codexDictation = nil; return }
                hold.control = try driver.pollCodexDictation(&hold.preparation)
                codexDictation = hold
                return
            }
            guard let control = hold.control, let deadline = hold.releaseDeadline else { return }
            if try driver.finishCodexDictation(control, deadlineReached: force || .now >= deadline) {
                codexDictation = nil
            }
        } catch {
            codexDictation = nil
            lastVoiceDiagnostic = "Codex AX 语音输出被阻止：\(error.localizedDescription)"
            throw error
        }
    }

    func releaseHeldKeys() throws {
        var firstError: Error?
        do { try stopCodexNativeDictation() } catch { firstError = error }
        requestCodexRelease()
        do { try advanceDictationRelease() } catch { firstError = error }
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

    private func configuredCodexDictationShortcut() throws -> Shortcut? {
        struct Settings: Decodable { let globalDictationHotkey: String? }
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
        let url = home.appendingPathComponent(".codex-global-state.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url, options: .mappedIfSafe))
        return settings.globalDictationHotkey.flatMap(CodexNativeDictationShortcut.parse)
    }

    private func startCodexNativeDictation(input: Shortcut, output: Shortcut, pid: pid_t) throws {
        let current = CGEventSource.flagsState(.combinedSessionState)
        let modifiers = KeyModifier.allCases.filter { current.contains(flag(for: $0)) }
        // An extra physically held modifier would change the OS-global chord.
        guard Set(modifiers).isSubset(of: output.modifiers) else {
            throw DesktopControlError.unavailable("Release unrelated keyboard modifiers before holding L.")
        }
        let plan = NativeDictationHoldPlan(shortcut: output, alreadyHeld: Set(modifiers))
        let held = NativeCodexHold(input: input, output: output, plan: plan, pid: pid)
        // Retain the release before posting so a partial failure can clean up.
        nativeCodexHold = held
        do {
            let events = try makeNativeEvents(plan.down)
            _ = try driver.requireDestination(.codex)
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
                throw DesktopControlError.unavailable("Codex lost focus before the dictation shortcut.")
            }
            for event in events { event.post(tap: .cghidEventTap) }
            lastVoiceDiagnostic = "Codex · 原生快捷键 \(output.formatted) · 按下事件已发送"
        } catch {
            try? stopCodexNativeDictation()
            throw error
        }
    }

    private func stopCodexNativeDictation() throws {
        guard let hold = nativeCodexHold else { return }
        do {
            let events = try makeNativeEvents(hold.plan.up)
            // The OS-global release watcher must see key/modifier-up, even if
            // focus changed. This path can only release; it never presses a key
            // in a newly focused application.
            for event in events { event.post(tap: .cghidEventTap) }
            nativeCodexHold = nil
            lastVoiceDiagnostic = "Codex · 原生快捷键 \(hold.output.formatted) · 释放事件已发送"
        } catch {
            lastVoiceDiagnostic = "Codex 原生语音释放失败：\(error.localizedDescription)"
            throw error
        }
    }

    private func flag(for modifier: KeyModifier) -> CGEventFlags {
        switch modifier {
        case .command: .maskCommand
        case .option: .maskAlternate
        case .control: .maskControl
        case .shift: .maskShift
        }
    }

    private func makeNativeEvents(_ plan: [NativeDictationKeyEvent]) throws -> [CGEvent] {
        try plan.map { step in
            guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState),
                virtualKey: CGKeyCode(step.keyCode), keyDown: step.down) else {
                throw ShortcutEmissionError.eventCreationFailed
            }
            if step.isModifier { event.type = .flagsChanged }
            event.flags = step.modifiers.reduce(into: CGEventFlags()) { $0.insert(flag(for: $1)) }
            return event
        }
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
