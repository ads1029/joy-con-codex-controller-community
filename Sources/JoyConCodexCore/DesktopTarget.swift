import Foundation
import CoreGraphics

public enum DesktopTarget: String, CaseIterable, Codable, Sendable, Identifiable {
    case codex
    case claudeCode

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        }
    }
    public var bundleIdentifier: String {
        switch self {
        case .codex: "com.openai.codex"
        case .claudeCode: "com.anthropic.claudefordesktop"
        }
    }
    public var other: Self { self == .codex ? .claudeCode : .codex }
}

/// These are desktop UI operations, never terminal commands.
public enum DesktopUIAction: Equatable, Sendable {
    case adjustEffort(increase: Bool)
    case focusPrompt(DesktopPromptSide)
}

public enum DesktopPromptSide: String, Sendable {
    case left, right
}

public protocol DesktopUIActionEmitting: ShortcutEmitting {
    func emit(_ action: DesktopUIAction) throws
}

public enum DesktopPromptSelection {
    /// Return the original index, based on visible AX geometry, never traversal order.
    public static func index(for side: DesktopPromptSide, frames: [CGRect], window: CGRect) -> Int? {
        let visible = frames.indices.filter {
            let rect = frames[$0]
            return !rect.isNull && !rect.isInfinite && rect.width >= 40 && rect.height >= 12
                && window.contains(CGPoint(x: rect.midX, y: rect.midY))
        }.sorted { frames[$0].minX < frames[$1].minX }
        guard visible.count == 2 else { return nil }
        let left = frames[visible[0]], right = frames[visible[1]]
        guard left.maxX <= right.minX,
              max(left.minY, right.minY) < min(left.maxY, right.maxY) else { return nil }
        return side == .left ? visible[0] : visible[1]
    }
}

public enum DesktopShortcutOutput: Equatable, Sendable {
    case keyboard(Shortcut)
    case interface(DesktopUIAction)
    case dictation
}

public enum DesktopShortcutResolver {
    public static func resolve(_ shortcut: Shortcut, for target: DesktopTarget,
        phase: ShortcutEmissionPhase = .tap) -> DesktopShortcutOutput {
        // Existing profiles encode the voice hold as ⌃⇧D. Keep their data and
        // custom taps intact; only the held mapping selects native dictation.
        if phase == .keyDown, shortcut.keyCode == 2, shortcut.modifiers == [.control, .shift] {
            return .dictation
        }
        guard target == .claudeCode else { return .keyboard(shortcut) }
        // Preserve the imported physical layout while translating known Codex
        // operations to Claude Desktop. Unrecognized custom shortcuts pass through.
        switch (shortcut.keyCode, shortcut.modifiers) {
        case (1, [.command, .option]):
            return .keyboard(Shortcut(keyCode: 41, displayLabel: ";", modifiers: [.command]))
        case (11, [.command, .option]):
            return .keyboard(Shortcut(keyCode: 2, displayLabel: "D", modifiers: [.command, .shift]))
        case (124, [.control, .option]): return .interface(.adjustEffort(increase: true))
        case (123, [.control, .option]): return .interface(.adjustEffort(increase: false))
        default: return .keyboard(shortcut)
        }
    }
}

/// Codex shortcuts require its foreground application, not a Claude-style AX
/// composer. Claude's split panes still require an unambiguous active prompt.
public enum DesktopActivationPolicy {
    public static func complete(for target: DesktopTarget,
        validateDestination: () throws -> Void,
        focusPrompt: () throws -> Void) throws {
        try validateDestination()
        if target == .claudeCode { try focusPrompt() }
    }
}

public enum DesktopAccessibilityPolicy {
    public static func isCodePage(title: String, url: String, selectedCode: Bool) -> Bool {
        if let components = URLComponents(string: url), let host = components.host {
            // The outer page route outranks stale or unavailable selector state.
            guard host == "claude.ai" else { return false }
            return components.path == "/code" || components.path.hasPrefix("/code/")
                || components.path.hasPrefix("/epitaxy/")
        }
        return selectedCode
    }

    public static func isPrompt(_ label: String) -> Bool {
        ["提示词", "Prompt", "Message Claude", "向 Claude 发送消息",
         "输入您发送给 Claude 的提示词", "撰写您给 Claude 的回复"].contains(label)
    }

    public static func isConversation(_ label: String) -> Bool {
        ["对话消息", "Conversation messages", "Chat messages", "会话消息"].contains(label)
    }
}

/// Only these exact composer labels may start or stop Codex dictation. In
/// particular "Transcribe and send" is a separate action and is never pressed.
public enum CodexDictationButton: Equatable, Sendable {
    case idle, starting, recording

    public init?(label: String) {
        // AXTitle/AXDescription can include whitespace or a shortcut on the
        // next line. Match a complete semantic line, never a broad substring.
        let first = label.split(whereSeparator: \.isNewline).first.map(String.init) ?? label
        let name = first.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "Dictate", "听写", "聽寫": self = .idle
        case "Starting dictation; click to cancel", "正在启动听写；点击可取消",
             "正在啟動聽寫，按一下即可取消", "正在開始聽寫；按一下即可取消": self = .starting
        case "Stop dictation", "停止听写", "停止聽寫", "停止口述": self = .recording
        default: return nil
        }
    }

    public enum Release: Equatable, Sendable {
        case wait, press, abandon
    }

    /// During startup Codex's same button cancels rather than transcribes.
    /// Give it time to enter recording; cancel only if startup never settles.
    public static func release(for state: Self?, deadlineReached: Bool) -> Release {
        switch state {
        case .recording: .press
        case .starting: deadlineReached ? .press : .wait
        case .idle, nil: deadlineReached ? .abandon : .wait
        }
    }
}

/// Electron's AXManualAccessibility is not implemented by every Chromium host.
/// Only fall back to Chromium's activation attribute when the manual request
/// is unsupported, or when its successful request still exposes only a shell.
public enum CodexAccessibilityActivation {
    public static func enable(request: (String) -> Bool) -> String? {
        for name in ["AXManualAccessibility", "AXEnhancedUserInterface"] {
            if request(name) { return name }
        }
        return nil
    }
}

public enum CodexDictationPreparationPolicy {
    public enum Step: Equatable, Sendable { case cancel, wait, start, fail }
    public static func next(isHeld: Bool, ready: Bool, timedOut: Bool) -> Step {
        guard isHeld else { return .cancel }
        if ready { return .start }
        return timedOut ? .fail : .wait
    }
}

/// Start only an enabled, visible, pressable microphone whose semantic names
/// agree. Ignore unrelated AXHelp text; conflicting known actions fail closed.
public enum CodexDictationRecognition {
    public static func state(names: [String]) -> CodexDictationButton? {
        let forbidden = ["Send", "发送", "傳送", "Transcribe and send", "转录并发送", "轉錄並傳送"]
        guard !names.contains(where: {
            let first = $0.split(whereSeparator: \.isNewline).first.map(String.init) ?? $0
            return forbidden.contains(first.trimmingCharacters(in: .whitespacesAndNewlines))
        }) else { return nil }
        let states = names.compactMap(CodexDictationButton.init(label:))
        guard let first = states.first, states.allSatisfy({ $0 == first }) else { return nil }
        return first
    }

    public static func isStartCandidate(role: String, names: [String],
        enabled: Bool, hidden: Bool, pressable: Bool, frame: CGRect, window: CGRect) -> Bool {
        let roles = ["AXButton", "AXCheckBox", "AXToggleButton"]
        return roles.contains(role) && enabled && !hidden && pressable && state(names: names) == .idle
            && !frame.isNull && !frame.isInfinite && frame.width >= 10 && frame.height >= 10
            && window.contains(CGPoint(x: frame.midX, y: frame.midY))
    }
}

/// Read only the configured *hold* shortcut. Never substitute the toggle
/// shortcut or change Codex's own settings.
public enum CodexNativeDictationShortcut {
    public static func parse(_ accelerator: String) -> Shortcut? {
        let parts = accelerator.split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard parts.count >= 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
        var modifiers = Set<KeyModifier>()
        var key: KeyOption?
        for part in parts {
            let modifier: KeyModifier? = switch part {
            case "ctrl", "control": .control
            case "shift": .shift
            case "cmd", "command", "meta", "super": .command
            case "alt", "option": .option
            default: nil
            }
            if let modifier {
                guard modifiers.insert(modifier).inserted else { return nil }
            } else {
                guard key == nil,
                      let option = KeyCatalog.options.first(where: { $0.label.lowercased() == part }) else { return nil }
                key = option
            }
        }
        guard let key, !modifiers.isEmpty else { return nil }
        return Shortcut(keyCode: key.keyCode, displayLabel: key.label, modifiers: modifiers)
    }
}

public struct NativeDictationKeyEvent: Equatable, Sendable {
    public let keyCode: UInt16
    public let down: Bool
    public let isModifier: Bool
    public let modifiers: Set<KeyModifier>
}

/// Unlike an in-app chord, a native global hold listener observes modifier
/// transitions and release state. Keep down/up balanced and don't release
/// modifiers that were already physically held when this controller began.
public struct NativeDictationHoldPlan: Sendable {
    public let down: [NativeDictationKeyEvent]
    public let up: [NativeDictationKeyEvent]

    public init(shortcut: Shortcut, alreadyHeld: Set<KeyModifier> = []) {
        let ordered: [(KeyModifier, UInt16)] = [(.control, 59), (.option, 58), (.shift, 56), (.command, 55)]
        let owned = ordered.filter { shortcut.modifiers.contains($0.0) && !alreadyHeld.contains($0.0) }
        var flags = alreadyHeld
        var start: [NativeDictationKeyEvent] = []
        for (modifier, keyCode) in owned {
            flags.insert(modifier)
            start.append(NativeDictationKeyEvent(keyCode: keyCode, down: true,
                isModifier: true, modifiers: flags))
        }
        flags.formUnion(shortcut.modifiers)
        start.append(NativeDictationKeyEvent(keyCode: shortcut.keyCode, down: true,
            isModifier: false, modifiers: flags))
        var stop = [NativeDictationKeyEvent(keyCode: shortcut.keyCode, down: false,
            isModifier: false, modifiers: flags)]
        for (modifier, keyCode) in owned.reversed() {
            flags.remove(modifier)
            stop.append(NativeDictationKeyEvent(keyCode: keyCode, down: false,
                isModifier: true, modifiers: flags))
        }
        down = start
        up = stop
    }
}
