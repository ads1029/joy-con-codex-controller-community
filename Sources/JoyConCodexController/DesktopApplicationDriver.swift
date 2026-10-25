import AppKit
import ApplicationServices
import JoyConCodexCore

enum DesktopControlError: LocalizedError {
    case unavailable(String)
    var errorDescription: String? {
        switch self { case .unavailable(let message): message }
    }
}

/// No application content is stored. AX references are scoped to a fresh focused
/// window, with a bounded traversal and no coordinate guesses between panes.
final class DesktopApplicationDriver {
    struct DictationControl {
        let pid: pid_t
        let point: CGPoint
        let prompt: AXUIElement
    }
    private var codePageCache: (window: AXUIElement, page: AXUIElement)?
    private var scrollCache: (pid: pid_t, prompt: AXUIElement, area: AXUIElement)?
    private var rememberedPrompt: (pid: pid_t, window: AXUIElement, prompt: AXUIElement)?
    private var chatGPTScrollCache: (pid: pid_t, window: AXUIElement, composer: AXUIElement, area: AXUIElement)?
    private var chatGPTAccessibilityPID: pid_t?
    private(set) var lastChatGPTScrollGeometry = ""
    struct Node {
        let element: AXUIElement
        let role: String
        let label: String
        let title: String
        let url: String
        let selected: Bool
    }

    func application(for target: DesktopTarget) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier).first
    }

    func isFrontmost(_ target: DesktopTarget) -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == target.bundleIdentifier
    }

    func requireDestination(_ target: DesktopTarget) throws -> NSRunningApplication {
        guard AccessibilityPermission.isTrusted() else {
            throw ShortcutEmissionError.accessibilityPermissionRequired
        }
        guard let application = application(for: target), isFrontmost(target) else {
            throw DesktopControlError.unavailable("Focus \(target.displayName) before sending input.")
        }
        if target == .claudeCode, !isCodeWindow(try window(of: application)) {
            throw DesktopControlError.unavailable("Claude is not on its Code page; input was blocked.")
        }
        return application
    }

    @MainActor
    func activate(_ target: DesktopTarget) async throws {
        guard AccessibilityPermission.isTrusted() else {
            throw ShortcutEmissionError.accessibilityPermissionRequired
        }
        if application(for: target) == nil {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: target.bundleIdentifier) else {
                throw DesktopControlError.unavailable("\(target.displayName) is not installed.")
            }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        }
        try Task.checkCancellation()
        guard let application = application(for: target) else {
            throw DesktopControlError.unavailable("\(target.displayName) did not start.")
        }
        _ = application.activate(options: [])
        for _ in 0..<20 {
            try Task.checkCancellation()
            if isFrontmost(target) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        guard isFrontmost(target) else {
            throw DesktopControlError.unavailable("Could not focus \(target.displayName).")
        }
        if target == .claudeCode {
            try await prepareClaudeAccessibility(application)
            let initial = try window(of: application)
            if !isCodeWindow(initial) {
                guard let code = scan(initial).first(where: {
                    $0.role == kAXRadioButtonRole && $0.label == "Code"
                }) else { throw DesktopControlError.unavailable("Claude's Code selector was not accessible.") }
                try press(code.element)
            }
            var ready = false
            for _ in 0..<20 {
                try Task.checkCancellation()
                guard isFrontmost(target) else { break }
                if let current = try? window(of: application), isCodeWindow(current) { ready = true; break }
                try await Task.sleep(for: .milliseconds(75))
            }
            guard ready else { throw DesktopControlError.unavailable("Claude's Code page is not ready.") }
        }
        try Task.checkCancellation()
        try DesktopActivationPolicy.complete(for: target, validateDestination: {
            _ = try requireDestination(target)
        }, focusPrompt: {
            let window = try window(of: application)
            let prompt = try activePrompt(in: window, application: application)
            guard AXUIElementSetAttributeValue(prompt, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else {
                throw DesktopControlError.unavailable("Click the intended prompt once, then focus the target again.")
            }
        })
    }

    @MainActor
    private func prepareClaudeAccessibility(_ application: NSRunningApplication) async throws {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        var enableResult: AXError = .success
        // Electron documents AXManualAccessibility for third-party assistive
        // apps. Request only for Claude, at explicit/first-stick activation.
        // Do not use AXEnhancedUserInterface, which changes window behavior.
        let ready = try await DesktopAccessibilityReadiness.prepare(enable: {
            enableResult = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            codePageCache = nil
        }, isReady: {
            guard isFrontmost(.claudeCode), let window = try? window(of: application) else { return false }
            return scan(window, stopAtWebArea: true).contains(where: { $0.role == "AXWebArea" })
        }, pause: {
            try await Task.sleep(for: .milliseconds(100))
        })
        guard ready else {
            throw DesktopControlError.unavailable(
                "Claude has not exposed its web accessibility tree (AXManualAccessibility: \(enableResult.rawValue)). Use Focus to retry; no input was sent.")
        }
    }

    func focusPrompt(_ side: DesktopPromptSide) throws {
        let application = try requireDestination(.claudeCode)
        let window = try window(of: application)
        guard let bounds = frame(of: window) else {
            throw DesktopControlError.unavailable("Claude's window geometry is unavailable.")
        }
        var prompts: [(element: AXUIElement, frame: CGRect)] = []
        for node in scan(window) where
            (node.role == kAXTextAreaRole || node.role == kAXTextFieldRole)
                && DesktopAccessibilityPolicy.isPrompt(node.label) {
            if let rect = frame(of: node.element), !prompts.contains(where: { CFEqual($0.element, node.element) }) {
                prompts.append((node.element, rect))
            }
        }
        guard let index = DesktopPromptSelection.index(for: side, frames: prompts.map(\.frame), window: bounds) else {
            throw DesktopControlError.unavailable("Left/right input selection requires two visible side-by-side prompts; nothing was selected.")
        }
        let current = try requireDestination(.claudeCode)
        guard current.processIdentifier == application.processIdentifier,
              CFEqual(try self.window(of: current), window) else {
            throw DesktopControlError.unavailable("Claude's window changed before input selection.")
        }
        let prompt = prompts[index].element
        guard AXUIElementSetAttributeValue(prompt, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success else {
            throw DesktopControlError.unavailable("Claude rejected focus on the \(side.rawValue) input.")
        }
        rememberedPrompt = (application.processIdentifier, window, prompt)
        scrollCache = nil
    }

    func conversationPoint(for target: DesktopTarget) throws -> CGPoint {
        let application = try requireDestination(target)
        let window = try window(of: application)
        if target == .codex { return try chatGPTConversationPoint(application: application, window: window) }
        let prompt = try activePrompt(in: window, application: application)
        if let cached = scrollCache, cached.pid == application.processIdentifier,
           CFEqual(cached.prompt, prompt), let frame = frame(of: cached.area) {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        // The closest common pane contains its own prompt and conversation. This
        // avoids choosing the other conversation in Claude's split view.
        var ancestor: AXUIElement? = prompt
        for _ in 0..<12 {
            guard let current = ancestor else { break }
            let conversations = scan(current).filter { DesktopAccessibilityPolicy.isConversation($0.label) }
            if conversations.count == 1, let frame = frame(of: conversations[0].element), frame.width > 100, frame.height > 60 {
                scrollCache = (application.processIdentifier, prompt, conversations[0].element)
                return CGPoint(x: frame.midX, y: frame.midY)
            }
            ancestor = attribute(current, kAXParentAttribute)
        }
        // Codex versions without a named conversation expose the focused pane's
        // scroll area. Never fall back to another app or a whole-window center.
        ancestor = prompt
        for _ in 0..<10 {
            guard let current = ancestor else { break }
            let areas = scan(current).filter { $0.role == kAXScrollAreaRole }.filter {
                guard let frame = frame(of: $0.element) else { return false }
                return frame.width > 250 && frame.height > 180
            }
            if areas.count == 1, let frame = frame(of: areas[0].element) {
                scrollCache = (application.processIdentifier, prompt, areas[0].element)
                return CGPoint(x: frame.midX, y: frame.midY)
            }
            ancestor = attribute(current, kAXParentAttribute)
        }
        throw DesktopControlError.unavailable("The active conversation scroll area is ambiguous or inaccessible.")
    }

    private func chatGPTConversationPoint(application: NSRunningApplication, window: AXUIElement) throws -> CGPoint {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        if chatGPTAccessibilityPID != application.processIdentifier {
            // Same Electron-supported request as Claude; keyboard readiness
            // remains independent of page/prompt matching.
            _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            chatGPTAccessibilityPID = application.processIdentifier
        }
        guard let bounds = frame(of: window) else {
            throw DesktopControlError.unavailable("ChatGPT's focused window geometry is unavailable.")
        }
        func legacyPoint(reason: String) throws -> CGPoint {
            guard let point = ChatGPTConversationScroll.legacyWindowPoint(window: bounds) else {
                throw DesktopControlError.unavailable("ChatGPT's focused window is too small or invalid for legacy scroll routing.")
            }
            lastChatGPTScrollGeometry = "mode=legacy-window; reason=\(reason); point=\(Int(point.x)),\(Int(point.y)); window=\(Int(bounds.minX)),\(Int(bounds.minY)),\(Int(bounds.width)),\(Int(bounds.height))"
            return point
        }
        func editableInput(_ element: AXUIElement) -> Bool {
            let role: String = attribute(element, kAXRoleAttribute) ?? ""
            guard let rect = frame(of: element) else { return false }
            return ChatGPTConversationScroll.isInputAnchor(role: role, frame: rect, window: bounds)
        }
        var composer: AXUIElement?
        var focused: AXUIElement? = attribute(app, kAXFocusedUIElementAttribute)
        var focusRoles: [String] = []
        for _ in 0..<10 {
            guard let current = focused else { break }
            focusRoles.append((attribute(current, kAXRoleAttribute) as String?) ?? "?")
            if editableInput(current) { composer = current; break }
            focused = attribute(current, kAXParentAttribute)
        }
        let cached = chatGPTScrollCache
        if composer == nil, let cached, cached.pid == application.processIdentifier,
           CFEqual(cached.window, window), editableInput(cached.composer) {
            composer = cached.composer
        }
        var inspectedNodes: [Node]?
        if composer == nil {
            let nodes = scan(window)
            inspectedNodes = nodes
            let inputs = nodes.filter {
                ($0.role == kAXTextAreaRole || $0.role == kAXTextFieldRole) && editableInput($0.element)
            }
            let textAreas = inputs.filter { $0.role == kAXTextAreaRole }
            if textAreas.count == 1 { composer = textAreas[0].element }
            else if textAreas.isEmpty, inputs.count == 1 { composer = inputs[0].element }
        }
        guard let composer, let composerFrame = frame(of: composer) else {
            let nodes = inspectedNodes ?? []
            let textAreas = nodes.filter { $0.role == kAXTextAreaRole }.count
            let fields = nodes.filter { $0.role == kAXTextFieldRole }.count
            let webAreas = nodes.filter { $0.role == "AXWebArea" }.count
            return try legacyPoint(reason: "input-anchor; focus=\(focusRoles.joined(separator: ">")); textAreas=\(textAreas); fields=\(fields); webAreas=\(webAreas); nodes=\(nodes.count)")
        }
        if let cached, cached.pid == application.processIdentifier,
           CFEqual(cached.window, window), CFEqual(cached.composer, composer),
           let area = frame(of: cached.area),
           let point = ChatGPTConversationScroll.point(window: bounds, composer: composerFrame, regions: [area]) {
            lastChatGPTScrollGeometry = scrollGeometry(point: point, composer: composerFrame, area: area, window: bounds)
            return point
        }
        chatGPTScrollCache = nil
        // Scan once, then route within the selected editable input's column.
        // Claude's localized prompt-label matcher is never used for ChatGPT.
        let regions = (inspectedNodes ?? scan(window)).filter {
            $0.role == kAXScrollAreaRole || DesktopAccessibilityPolicy.isConversation($0.label)
        }.compactMap { node -> (AXUIElement, CGRect)? in
            guard let rect = frame(of: node.element) else { return nil }
            return (node.element, rect)
        }
        if let route = ChatGPTConversationScroll.route(window: bounds, composer: composerFrame, regions: regions.map(\.1)) {
            let region = regions[route.regionIndex]
            chatGPTScrollCache = (application.processIdentifier, window, composer, region.0)
            lastChatGPTScrollGeometry = scrollGeometry(point: route.point, composer: composerFrame, area: region.1, window: bounds)
            return route.point
        }
        return try legacyPoint(reason: "conversation-region")
    }

    private func scrollGeometry(point: CGPoint, composer: CGRect, area: CGRect, window: CGRect) -> String {
        func rect(_ value: CGRect) -> String {
            "\(Int(value.minX)),\(Int(value.minY)),\(Int(value.width)),\(Int(value.height))"
        }
        return "mode=ax; point=\(Int(point.x)),\(Int(point.y)); input=\(rect(composer)); area=\(rect(area)); window=\(rect(window))"
    }

    func scrollHitRoles(at point: CGPoint, application: NSRunningApplication) -> String {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        var hit: AXUIElement?
        let status = AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit)
        guard status == .success, let hit else { return "hitAX=\(status.rawValue)" }
        var roles: [String] = []
        var element: AXUIElement? = hit
        for _ in 0..<5 {
            guard let current = element else { break }
            let role: String = attribute(current, kAXRoleAttribute) ?? "?"
            roles.append(role)
            element = attribute(current, kAXParentAttribute)
        }
        return "hit=" + roles.joined(separator: ">")
    }

    func dictationControl() throws -> DictationControl {
        let application = try requireDestination(.claudeCode)
        let window = try window(of: application)
        let prompt = try activePrompt(in: window, application: application)
        var ancestor: AXUIElement? = prompt
        for _ in 0..<10 {
            guard let current = ancestor else { break }
            let buttons = scan(current).filter { node in
                guard ["按住以录音", "Hold to record", "Hold to dictate"].contains(node.label) else { return false }
                var actions: CFArray?
                return AXUIElementCopyActionNames(node.element, &actions) == .success
                    && (actions as? [String])?.contains(kAXPressAction) == true
            }
            if buttons.count == 1, let rect = frame(of: buttons[0].element),
               rect.width > 10, rect.height > 10, let bounds = frame(of: window) {
                let point = CGPoint(x: rect.midX, y: rect.midY)
                guard bounds.contains(point) else { break }
                return DictationControl(pid: application.processIdentifier, point: point, prompt: prompt)
            }
            ancestor = attribute(current, kAXParentAttribute)
        }
        throw DesktopControlError.unavailable("Claude's active prompt must expose Hold to record; no audio was started.")
    }

    func restorePrompt(after control: DictationControl) {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == control.pid else { return }
        _ = AXUIElementSetAttributeValue(control.prompt, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    func adjustEffort(increase: Bool, target: DesktopTarget,
        sendKey: (Shortcut) throws -> Void) throws {
        let application = try requireDestination(target)
        let window = try window(of: application)
        let prompt = try activePrompt(in: window, application: application)
        var ancestor: AXUIElement? = prompt
        var modelButton: AXUIElement?
        for _ in 0..<10 {
            guard let current = ancestor else { break }
            let matches = scan(current).filter {
                $0.role == kAXPopUpButtonRole && ($0.label.hasPrefix("模型：") || $0.label.hasPrefix("Model:"))
            }
            if matches.count == 1 { modelButton = matches[0].element; break }
            ancestor = attribute(current, kAXParentAttribute)
        }
        guard let modelButton else { throw DesktopControlError.unavailable("The active prompt's model selector was not found.") }
        try press(modelButton)
        defer {
            // AXCancel affects only an actual open menu. Sending Escape after a
            // successful selection could instead stop a running Claude response.
            if isFrontmost(target) { cancelEffortMenus(application: application) }
        }
        guard let effort = waitForNode(application: application, matching: {
            $0.label.hasPrefix("思考强度") || $0.label.hasPrefix("Effort")
        }) else { throw DesktopControlError.unavailable("Claude's effort menu is unavailable for this model.") }
        _ = try requireDestination(target)
        try press(effort.element)
        try sendKey(Shortcut(keyCode: 124, displayLabel: "Right Arrow"))
        let ranks = ["低", "中等", "高", "超高", "最高", "Ultracode"]
        let english = ["Low", "Medium", "High", "Extra high", "Max", "Ultracode"]
        guard waitForNode(application: application, matching: {
            $0.role == kAXMenuItemRole && ($0.label.hasPrefix("低") || $0.label.hasPrefix("Low"))
        }) != nil else { throw DesktopControlError.unavailable("Claude's effort submenu did not open.") }
        let nodes = scan(AXUIElementCreateApplication(application.processIdentifier))
        var options: [(rank: Int, node: Node)] = []
        for node in nodes where node.role == kAXMenuItemRole {
            if let rank = ranks.indices.first(where: { node.label.hasPrefix(ranks[$0]) || node.label.hasPrefix(english[$0]) }) {
                options.append((rank, node))
            }
        }
        options.sort { $0.rank < $1.rank }
        guard let index = options.firstIndex(where: { $0.node.selected }) else {
            throw DesktopControlError.unavailable("Claude's selected effort could not be determined; nothing changed.")
        }
        let next = max(0, min(options.count - 1, index + (increase ? 1 : -1)))
        guard next != index else { return }
        _ = try requireDestination(target)
        try press(options[next].node.element)
    }

    private func waitForNode(application: NSRunningApplication, matching: (Node) -> Bool) -> Node? {
        for _ in 0..<12 {
            if let node = scan(AXUIElementCreateApplication(application.processIdentifier)).first(where: matching) { return node }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return nil
    }

    private func cancelEffortMenus(application: NSRunningApplication) {
        for node in scan(AXUIElementCreateApplication(application.processIdentifier)).reversed() {
            guard node.label.hasPrefix("模型：") || node.label.hasPrefix("Model:")
                || node.label.hasPrefix("思考强度") || node.label.hasPrefix("Effort") else { continue }
            var actions: CFArray?
            if AXUIElementCopyActionNames(node.element, &actions) == .success,
               let names = actions as? [String], names.contains(kAXCancelAction) {
                _ = AXUIElementPerformAction(node.element, kAXCancelAction as CFString)
            }
        }
    }

    private func isCodeWindow(_ window: AXUIElement) -> Bool {
        // Electron can omit the radio button's AXValue. Read the outer page's
        // current URL first; a missing/false radio value must not hide a Code URL.
        if let cached = codePageCache, CFEqual(cached.window, window) {
            let url = pageURL(cached.page)
            if URLComponents(string: url)?.host == "claude.ai" {
                return DesktopAccessibilityPolicy.isCodePage(title: "", url: url, selectedCode: false)
            }
        }
        let nodes = scan(window)
        // Check the outer Claude page, not an embedded artifact/browser frame.
        let page = nodes.first(where: {
            $0.role == "AXWebArea" && URLComponents(string: $0.url)?.host == "claude.ai"
        })
        if let page { codePageCache = (window, page.element) }
        let selectedCode = nodes.first(where: {
            $0.role == kAXRadioButtonRole && $0.label == "Code"
        })?.selected ?? false
        return DesktopAccessibilityPolicy.isCodePage(title: page?.title ?? "",
            url: page?.url ?? "", selectedCode: selectedCode)
    }

    private func pageURL(_ element: AXUIElement) -> String {
        if let url: URL = attribute(element, kAXURLAttribute) { return url.absoluteString }
        let string: String? = attribute(element, kAXURLAttribute)
        return string ?? ""
    }

    private func activePrompt(in window: AXUIElement, application: NSRunningApplication) throws -> AXUIElement {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        if let focused: AXUIElement = attribute(app, kAXFocusedUIElementAttribute) {
            var ancestor: AXUIElement? = focused
            for _ in 0..<10 {
                guard let current = ancestor else { break }
                let local = scan(current).filter {
                    ($0.role == kAXTextAreaRole || $0.role == kAXTextFieldRole)
                        && DesktopAccessibilityPolicy.isPrompt($0.label)
                }
                if local.count == 1 {
                    rememberedPrompt = (application.processIdentifier, window, local[0].element)
                    return local[0].element
                }
                ancestor = attribute(current, kAXParentAttribute)
            }
        }
        let prompts = scan(window).filter {
            ($0.role == kAXTextAreaRole || $0.role == kAXTextFieldRole)
                && DesktopAccessibilityPolicy.isPrompt($0.label)
        }
        // Electron sometimes reports the whole web area as focused. Reuse only
        // a prompt still present and visible in this exact process/window.
        if let remembered = rememberedPrompt,
           remembered.pid == application.processIdentifier, CFEqual(remembered.window, window),
           let match = prompts.first(where: { CFEqual($0.element, remembered.prompt) }),
           let rect = frame(of: match.element), let bounds = frame(of: window),
           rect.width >= 40, rect.height >= 12, bounds.contains(CGPoint(x: rect.midX, y: rect.midY)) {
            return match.element
        }
        rememberedPrompt = nil
        guard prompts.count == 1 else {
            throw DesktopControlError.unavailable("Select the intended prompt; multiple panes or no accessible prompt were found.")
        }
        return prompts[0].element
    }

    private func window(of application: NSRunningApplication) throws -> AXUIElement {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        guard let window: AXUIElement = attribute(app, kAXFocusedWindowAttribute) else {
            throw DesktopControlError.unavailable("The target has no accessible focused window.")
        }
        return window
    }

    private func press(_ element: AXUIElement) throws {
        guard AXUIElementPerformAction(element, kAXPressAction as CFString) == .success else {
            throw DesktopControlError.unavailable("The target control rejected its accessibility action.")
        }
    }

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position: AXValue = attribute(element, kAXPositionAttribute),
              let size: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    private func scan(_ root: AXUIElement, stopAtWebArea: Bool = false) -> [Node] {
        var stack = [root]
        var result: [Node] = []
        let deadline = Date().addingTimeInterval(0.6)
        while let element = stack.popLast(), result.count < 4_000, Date() < deadline {
            let role: String = attribute(element, kAXRoleAttribute) ?? ""
            let title: String = attribute(element, kAXTitleAttribute) ?? ""
            let description: String = attribute(element, kAXDescriptionAttribute) ?? ""
            let value: NSNumber? = role == kAXRadioButtonRole || role == kAXMenuItemRole
                ? attribute(element, kAXValueAttribute) : nil
            let mark: String = role == kAXMenuItemRole ? (attribute(element, kAXMenuItemMarkCharAttribute) ?? "") : ""
            result.append(Node(element: element, role: role,
                label: description.isEmpty ? title : description, title: title,
                url: role == "AXWebArea" ? pageURL(element) : "", selected: value?.boolValue == true || !mark.isEmpty))
            if stopAtWebArea, role == "AXWebArea" { break }
            let children: [AXUIElement] = attribute(element, kAXChildrenAttribute) ?? []
            stack.append(contentsOf: children.reversed())
        }
        return result
    }
}
