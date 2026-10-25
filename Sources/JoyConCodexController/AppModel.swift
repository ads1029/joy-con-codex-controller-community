import AppKit
import Combine
import Foundation
import JoyConCodexCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var controllers: [ControllerDescriptor] = []
    @Published private(set) var recentEvent: ControllerEvent?
    @Published private(set) var recentResult: MappingResult?
    @Published private(set) var statusMessage = "Starting controller discovery…"
    @Published private(set) var feedbackMessage = "Visual feedback is ready."
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var selectedTarget: DesktopTarget = .codex
    @Published private(set) var activationInProgress = false
    @Published private(set) var desktopLayoutMessage = "尚未记录桌面布局"
    @Published private(set) var restoringDesktopLayout = false
    @Published private(set) var desktopLayoutCandidates: [DesktopLayoutCandidate] = []
    @Published var desktopWindowSelections: [DesktopTarget: DesktopWindowIdentity] = [:]
    @Published var profile: MappingProfile
    @Published var leftJoyConOrientation: SingleJoyConOrientation {
        didSet {
            userDefaults?.set(
                leftJoyConOrientation.rawValue,
                forKey: Self.leftJoyConOrientationKey
            )
            releaseKeyboardState(reason: "Left Joy-Con orientation changed")
            adapter.setLeftJoyConOrientation(leftJoyConOrientation)
        }
    }
    @Published var focusTargetOnStickMove: Bool {
        didSet {
            userDefaults?.set(focusTargetOnStickMove, forKey: Self.focusTargetOnStickMoveKey)
        }
    }
    @Published var testMode: Bool {
        didSet {
            userDefaults?.set(testMode, forKey: Self.testModeKey)
            activationTask?.cancel()
            cancelDesktopRestore()
            activationInProgress = false
            activationFailureMessage = nil
            do {
                try session.outputModeChanged(emitter: emitter)
                feedbackMessage = testMode
                    ? "Test mode enabled. No input will be sent."
                    : "Live output enabled. Focus the selected app and release all controls before pressing again."
            } catch {
                feedbackMessage = "Output mode change blocked: \(error.localizedDescription)"
            }
        }
    }

    private static let testModeKey = "JoyConCodexController.testMode"
    private static let focusTargetOnStickMoveKey = "JoyConCodexController.focusTargetOnStickMove"
    private static let leftJoyConOrientationKey = "JoyConCodexController.leftJoyConOrientation"
    private static let requestAccessibilityLaunchArgument = "--request-accessibility"

    private let adapter: GameControllerAdapter
    private let emitter: CoreGraphicsShortcutEmitter
    private let desktopLayout: DesktopLayoutController
    private let codingHUD = CodingModeHUD()
    private var connectionTracker = ControllerConnectionTracker()
    private var desktopRestoreTask: Task<Void, Never>?
    private var desktopRestoreID: UUID?
    private var profileStore: ProfileStore?
    private var unifiedStore: UnifiedProfileStore?
    private var session = UnifiedControllerSession()
    private var activationTask: Task<Void, Never>?
    private var activationFailureMessage: String?
    private var mappingFailureMessage: String?
    private var clockTask: Task<Void, Never>?
    private let userDefaults: UserDefaults?
    init(userDefaults injectedDefaults: UserDefaults? = nil) {
        let userDefaults = injectedDefaults ?? UnifiedPreferences.make()
        self.userDefaults = userDefaults
        self.adapter = GameControllerAdapter()
        self.emitter = CoreGraphicsShortcutEmitter()
        self.desktopLayout = DesktopLayoutController(defaults: userDefaults)

        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: false)
            let unified = UnifiedProfileStore(applicationSupport: support)
            self.unifiedStore = unified
            let target = userDefaults?.string(forKey: "selectedTarget").flatMap(DesktopTarget.init(rawValue:)) ?? .codex
            self.selectedTarget = target
            self.session = UnifiedControllerSession(target: target)
            self.emitter.target = target
            self.profileStore = unified.store(for: target)
            let loadResult = unified.load(for: target)
            self.profile = loadResult.profile
            if let recovery = loadResult.recoveryMessage {
                self.statusMessage = recovery
            }
        } catch {
            self.profileStore = nil
            self.profile = .starter
            self.statusMessage = "Using defaults in memory: \(error.localizedDescription)"
        }

        if userDefaults?.object(forKey: Self.testModeKey) == nil {
            self.testMode = true
        } else {
            self.testMode = userDefaults?.bool(forKey: Self.testModeKey) ?? true
        }

        if userDefaults?.object(forKey: Self.focusTargetOnStickMoveKey) == nil {
            self.focusTargetOnStickMove = true
        } else {
            self.focusTargetOnStickMove = userDefaults?.bool(
                forKey: Self.focusTargetOnStickMoveKey
            ) ?? true
        }

        if
            let rawOrientation = userDefaults?.string(forKey: Self.leftJoyConOrientationKey),
            let orientation = SingleJoyConOrientation(rawValue: rawOrientation)
        {
            self.leftJoyConOrientation = orientation
        } else {
            self.leftJoyConOrientation = .portrait
        }

        let requestAccessibilityOnLaunch = ProcessInfo.processInfo.arguments.contains(
            Self.requestAccessibilityLaunchArgument
        )
        self.accessibilityTrusted = AccessibilityPermission.isTrusted(
            prompt: requestAccessibilityOnLaunch
        )
        if requestAccessibilityOnLaunch, !accessibilityTrusted {
            self.statusMessage = "Grant Accessibility to this installed build, then refresh permission."
        }
        if userDefaults == nil {
            self.statusMessage = "Unified preferences unavailable; preference changes stay in memory."
        }
        adapter.setLeftJoyConOrientation(leftJoyConOrientation)
        desktopLayoutMessage = desktopLayout.summary
        adapter.onControllersChanged = { [weak self] descriptors in
            self?.handleControllers(descriptors)
        }
        adapter.onEvent = { [weak self] event in
            self?.handle(event)
        }
        adapter.onInputSourceStatus = { [weak self] status in
            self?.feedbackMessage = status
        }
        if let inputSourceStatus = adapter.inputSourceStatus {
            feedbackMessage = inputSourceStatus
        }
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clockTask?.cancel()
                self?.cancelDesktopRestore()
                self?.releaseKeyboardState(reason: "Application terminating")
            }
        }
        clockTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(25)) }
                catch { return }
                self?.advanceClock()
            }
        }
        adapter.rescan()
    }

    var supportedControllers: [ControllerDescriptor] {
        controllers.filter(\.isSupported)
    }

    var unsupportedControllers: [ControllerDescriptor] {
        controllers.filter { !$0.isSupported }
    }

    var activeControllerBattery: ControllerBatteryStatus? {
        supportedControllers.first?.battery
    }

    var menuBarStatus: MenuBarStatus {
        MenuBarStatus(
            supportedControllerCount: supportedControllers.count,
            testMode: testMode,
            accessibilityTrusted: accessibilityTrusted
        )
    }

    func rescan() {
        statusMessage = "Scanning for controllers exposed by macOS…"
        adapter.rescan()
    }

    func requestAccessibilityPermission() {
        accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: true)
        statusMessage = accessibilityTrusted
            ? "Accessibility permission is available."
            : "Enable this app in System Settings → Privacy & Security → Accessibility."
    }

    func refreshAccessibilityPermission() {
        accessibilityTrusted = AccessibilityPermission.isTrusted()
    }

    func update(_ mapping: InputMapping) {
        var candidate = profile
        candidate.update(mapping)
        if let unifiedStore { candidate = unifiedStore.reservedControlsDisabled(candidate) }
        do {
            try candidate.validate()
            releaseKeyboardState(reason: "Mapping changed")
            profile = candidate
            try saveProfile()
            statusMessage = "Saved \(mapping.input.displayName)."
        } catch {
            statusMessage = "Mapping was not saved: \(error.localizedDescription)"
        }
    }

    func resetProfile() {
        do {
            releaseKeyboardState(reason: "Profile reset")
            if let profileStore {
                let imported = unifiedStore.map { ProfileStore(profileURL: $0.legacyProfileURL).load().profile } ?? .starter
                profile = unifiedStore?.adaptImportedBaseline(imported, for: selectedTarget) ?? imported
                try profileStore.save(profile)
            } else {
                profile = .starter
            }
            statusMessage = "Starter mappings restored."
        } catch {
            statusMessage = "Could not reset profile: \(error.localizedDescription)"
        }
    }

    func importProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a Joy-Con Unified Controller profile."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            guard let profileStore else {
                throw CocoaError(.fileNoSuchFile)
            }
            let source = try profileStore.importProfile(from: url)
            let imported = unifiedStore?.reservedControlsDisabled(source) ?? source
            try profileStore.save(imported)
            releaseKeyboardState(reason: "Profile imported")
            profile = imported
            statusMessage = "Imported \(imported.name)."
        } catch {
            statusMessage = "Import rejected: \(error.localizedDescription)"
        }
    }

    func exportProfile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "joy-con-codex-profile.json"
        panel.message = "Export the validated mapping profile."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            guard let profileStore else {
                throw CocoaError(.fileNoSuchFile)
            }
            if let legacy = unifiedStore?.legacyProfileURL,
               url.resolvingSymlinksInPath().standardizedFileURL == legacy.resolvingSymlinksInPath().standardizedFileURL {
                throw DesktopControlError.unavailable("The original controller profile is protected from export.")
            }
            try profileStore.export(profile, to: url)
            statusMessage = "Exported \(profile.name)."
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func saveProfile() throws {
        guard let profileStore else {
            throw CocoaError(.fileNoSuchFile)
        }
        try profileStore.save(profile)
    }

    var profileLocation: String { profileStore?.profileURL.path ?? "In-memory profile" }

    func selectTarget(_ target: DesktopTarget) {
        guard !restoringDesktopLayout else { return }
        guard target != selectedTarget else { return }
        consume(session.selectTarget(target, testMode: testMode, emitter: emitter))
    }

    func toggleTarget() { selectTarget(selectedTarget.other) }

    func focusTarget() {
        guard !restoringDesktopLayout else { return }
        do {
            let token = try suspendOutputThrowing()
            if testMode {
                session.completeActivation(generation: token)
                feedbackMessage = "Test mode: application focus is suppressed."
            } else { startActivation(generation: token) }
        } catch { feedbackMessage = "Focus blocked: \(error.localizedDescription)" }
    }

    private func handleControllers(_ descriptors: [ControllerDescriptor]) {
        let previous = supportedControllers.first?.id
        controllers = descriptors
        if let previous, previous != supportedControllers.first?.id {
            cancelDesktopRestore()
            activationTask?.cancel()
            activationInProgress = false
            do { try session.disconnected(emitter: emitter); try emitter.releaseHeldKeys() }
            catch { feedbackMessage = "Disconnect cleanup failed: \(error.localizedDescription)" }
        }
        statusMessage = supportedControllers.isEmpty ? "No supported Joy-Con connected." : "Joy-Con connected."
        if connectionTracker.update(Set(supportedControllers.map(\.id))) {
            if testMode {
                codingHUD.show(detail: "Joy-Con 已连接 · Test Mode · 自动恢复已暂停")
            } else {
                restoreDesktopLayout(showConnectionHUD: true)
            }
        }
    }

    func captureDesktopLayout() {
        guard !restoringDesktopLayout else { return }
        do {
            try refreshDesktopLayoutCandidates()
            guard DesktopTarget.allCases.allSatisfy({ desktopWindowSelections[$0] != nil }) else {
                desktopLayoutMessage = "检测到多个窗口，请在下方为 Codex / Claude 选择要恢复的窗口，再点记录。"
                return
            }
            try desktopLayout.capture(selections: desktopWindowSelections)
            desktopLayoutMessage = "已记录：\(desktopLayout.summary)"
        } catch { desktopLayoutMessage = "记录失败：\(error.localizedDescription)" }
    }

    private func refreshDesktopLayoutCandidates() throws {
        let candidates = try desktopLayout.candidates()
        desktopLayoutCandidates = candidates
        for target in DesktopTarget.allCases {
            let choices = candidates.filter { $0.target == target }
            if let selection = desktopWindowSelections[target], choices.contains(where: { $0.identity == selection }) { continue }
            desktopWindowSelections[target] = choices.count == 1 ? choices[0].identity : nil
        }
    }

    func previewCodingHUD() { codingHUD.show(detail: "HUD 预览 · 不移动窗口") }

    func restoreDesktopLayout(showConnectionHUD: Bool = false) {
        guard !testMode, !restoringDesktopLayout else { return }
        do {
            try emitter.requireExclusiveController()
            let token = try suspendOutputThrowing()
            let id = UUID()
            desktopRestoreID = id
            restoringDesktopLayout = true
            desktopLayoutMessage = "正在恢复桌面布局…"
            desktopRestoreTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    try await desktopLayout.restore()
                    try Task.checkCancellation()
                    guard desktopRestoreID == id else { return }
                    desktopLayoutMessage = "已恢复：\(desktopLayout.summary)"
                    if showConnectionHUD { codingHUD.show(detail: desktopLayout.summary) }
                } catch is CancellationError { return }
                catch {
                    guard desktopRestoreID == id else { return }
                    desktopLayoutMessage = "恢复未完成：\(error.localizedDescription)"
                    if showConnectionHUD { codingHUD.show(detail: "Joy-Con 已连接 · 桌面恢复未完成，请查看控制器") }
                }
                guard desktopRestoreID == id else { return }
                desktopRestoreID = nil
                restoringDesktopLayout = false
                desktopRestoreTask = nil
                session.completeActivation(generation: token)
            }
        } catch {
            desktopLayoutMessage = "恢复被阻止：\(error.localizedDescription)"
            if showConnectionHUD { codingHUD.show(detail: "Joy-Con 已连接 · 桌面恢复被阻止") }
        }
    }

    private func cancelDesktopRestore() {
        desktopRestoreTask?.cancel()
        desktopRestoreTask = nil
        desktopRestoreID = nil
        restoringDesktopLayout = false
    }

    private func handle(_ event: ControllerEvent) {
        recentEvent = event
        if restoringDesktopLayout {
            session.observeWhileSuspended(event)
            return
        }
        // Explicit pane selection can recover from an ambiguous-prompt activation
        // failure. Background apps still use the ordinary first-stick focus gate.
        if session.promptSelection(for: event) != nil, !session.heldInputs.contains(event.input),
           testMode || emitter.driver.isFrontmost(.claudeCode) {
            activationTask?.cancel()
            activationInProgress = false
            consume(session.process(event, profile: profile, testMode: testMode, emitter: emitter))
            return
        }
        if !testMode, !activationInProgress, focusTargetOnStickMove,
           CodexFocusTrigger.shouldFocus(for: event),
           (!session.isReady || !emitter.driver.isFrontmost(selectedTarget)) {
            do {
                let token = try session.holdForActivation(event, emitter: emitter)
                startActivation(generation: token)
            } catch { feedbackMessage = error.localizedDescription }
            return
        }
        consume(session.process(event, profile: profile, testMode: testMode, emitter: emitter))
    }

    private func advanceClock() {
        for result in session.advance(to: .now, testMode: testMode, emitter: emitter) { consume(result) }
    }

    private func consume(_ result: UnifiedSessionResult) {
        switch result {
        case .desktopAction(let action, let disposition):
            recentResult = nil
            if case .failed(let message) = disposition {
                let feedback = "Input selection blocked: \(message)"
                activationFailureMessage = feedback
                feedbackMessage = feedback
            } else if case .focusPrompt(let side) = action {
                activationFailureMessage = nil
                let label = side == .left ? "左侧输入框" : "右侧输入框"
                feedbackMessage = disposition == .suppressedByTestMode
                    ? "Test mode: \(label). No focus was changed."
                    : "Claude Code · \(label)；松开 ZL 和摇杆后，L 录音跟随此输入框。"
                if disposition == .emitted { _ = adapter.playConfirmation() }
            }
        case .targetChanged(let target, let generation):
            mappingFailureMessage = nil
            activationTask?.cancel()
            activationInProgress = false
            emitter.target = target
            selectedTarget = target
            userDefaults?.set(target.rawValue, forKey: "selectedTarget")
            profileStore = unifiedStore?.store(for: target)
            if let loaded = unifiedStore?.load(for: target) { profile = loaded.profile }
            recentResult = nil
            if testMode {
                feedbackMessage = "Test target: \(target.displayName). No application was activated."
            } else { startActivation(generation: generation) }
        case .mapping(let mapping):
            recentResult = mapping
            if case .failed(let message) = mapping.disposition {
                let failure = "Output blocked: \(message)"
                mappingFailureMessage = failure
                feedbackMessage = failure
            } else {
                if mapping.disposition == .emitted || mapping.disposition == .suppressedByTestMode {
                    mappingFailureMessage = nil
                }
                feedbackMessage = mappingFailureMessage
                    ?? "\(selectedTarget.displayName) · \(mapping.layer.rawValue) · \(mapping.action?.formatted ?? "Disabled")"
                if mappingFailureMessage == nil, selectedTarget == .codex,
                   mapping.action?.scrollCommand != nil, !emitter.lastScrollDiagnostics.isEmpty {
                    feedbackMessage += "\n" + emitter.lastScrollDiagnostics
                }
            }
            if mapping.disposition == .emitted, mapping.event.phase == .pressed { _ = adapter.playConfirmation() }
        case .failed(let message):
            let failure = "Output blocked: \(message)"
            mappingFailureMessage = failure
            feedbackMessage = failure
        case .suppressed:
            if session.awaitingNeutral { feedbackMessage = "Release all controls before continuing with \(selectedTarget.displayName)." }
            else if !session.isReady {
                feedbackMessage = activationFailureMessage
                    ?? "\(selectedTarget.displayName) is not ready. Use the Focus button to retry; no input was sent."
            }
        }
        accessibilityTrusted = AccessibilityPermission.isTrusted()
    }

    private func startActivation(generation: UInt64) {
        activationTask?.cancel()
        activationInProgress = true
        activationFailureMessage = nil
        mappingFailureMessage = nil
        let target = selectedTarget
        feedbackMessage = "Focusing \(target.displayName)…"
        activationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try emitter.requireExclusiveController()
                try await emitter.driver.activate(target)
                try Task.checkCancellation()
                guard session.generation == generation, selectedTarget == target else { return }
                session.completeActivation(generation: generation)
                activationInProgress = false
                feedbackMessage = session.awaitingNeutral ? "\(target.displayName) ready; release all controls." : "\(target.displayName) ready."
            } catch is CancellationError { return }
            catch {
                guard session.generation == generation else { return }
                activationInProgress = false
                let message = "\(target.displayName) blocked: \(error.localizedDescription)"
                activationFailureMessage = message
                feedbackMessage = message
            }
        }
    }

    @discardableResult
    private func suspendOutputThrowing() throws -> UInt64 {
        activationTask?.cancel()
        activationInProgress = false
        activationFailureMessage = nil
        return try session.suspend(emitter: emitter)
    }

    private func releaseKeyboardState(reason: String) {
        do {
            let token = try suspendOutputThrowing()
            if testMode { session.completeActivation(generation: token) }
        } catch { feedbackMessage = "\(reason): \(error.localizedDescription)" }
    }
}
