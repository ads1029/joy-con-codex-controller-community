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
}

public enum DesktopShortcutResolver {
    public static func resolve(_ shortcut: Shortcut, for target: DesktopTarget) -> DesktopShortcutOutput {
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
        ["提示词", "Prompt", "Message Claude", "向 Claude 发送消息"].contains(label)
    }

    public static func isConversation(_ label: String) -> Bool {
        ["对话消息", "Conversation messages", "Chat messages", "会话消息"].contains(label)
    }
}
