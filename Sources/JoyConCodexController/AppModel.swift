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
    @Published var profile: MappingProfile
    @Published var leftJoyConOrientation: SingleJoyConOrientation {
        didSet {
            userDefaults.set(
                leftJoyConOrientation.rawValue,
                forKey: Self.leftJoyConOrientationKey
            )
            releaseKeyboardState(reason: "Left Joy-Con orientation changed")
            adapter.setLeftJoyConOrientation(leftJoyConOrientation)
        }
    }
    @Published var focusCodexOnStickMove: Bool {
        didSet {
            userDefaults.set(focusCodexOnStickMove, forKey: Self.focusCodexOnStickMoveKey)
        }
    }
    @Published var testMode: Bool {
        didSet {
            userDefaults.set(testMode, forKey: Self.testModeKey)
            if testMode {
                releaseKeyboardState(reason: "Test mode enabled")
            } else {
                mappingEngine.resetPressedState()
            }
        }
    }

    private static let testModeKey = "JoyConCodexController.testMode"
    private static let focusCodexOnStickMoveKey = "JoyConCodexController.focusCodexOnStickMove"
    private static let leftJoyConOrientationKey = "JoyConCodexController.leftJoyConOrientation"
    private static let codexBundleIdentifier = "com.openai.codex"
    private static let requestAccessibilityLaunchArgument = "--request-accessibility"

    private let adapter: GameControllerAdapter
    private let emitter: CoreGraphicsShortcutEmitter
    private let profileStore: ProfileStore?
    private let userDefaults: UserDefaults
    private var mappingEngine = MappingEngine()
    private var repeatTasks: [ControllerInput: Task<Void, Never>] = [:]
    private var tapSequenceRecognizer = TapSequenceRecognizer()
    private var pendingSingleTapTasks: [ControllerInput: Task<Void, Never>] = [:]
    private var pendingSingleTapEvents: [ControllerInput: ControllerEvent] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.adapter = GameControllerAdapter()
        self.emitter = CoreGraphicsShortcutEmitter()

        do {
            let store = try ProfileStore.applicationSupport()
            self.profileStore = store
            let loadResult = store.load()
            self.profile = loadResult.profile
            if let recovery = loadResult.recoveryMessage {
                self.statusMessage = recovery
            }
        } catch {
            self.profileStore = nil
            self.profile = .starter
            self.statusMessage = "Using defaults in memory: \(error.localizedDescription)"
        }

        if userDefaults.object(forKey: Self.testModeKey) == nil {
            self.testMode = true
        } else {
            self.testMode = userDefaults.bool(forKey: Self.testModeKey)
        }

        if userDefaults.object(forKey: Self.focusCodexOnStickMoveKey) == nil {
            self.focusCodexOnStickMove = true
        } else {
            self.focusCodexOnStickMove = userDefaults.bool(
                forKey: Self.focusCodexOnStickMoveKey
            )
        }

        if
            let rawOrientation = userDefaults.string(forKey: Self.leftJoyConOrientationKey),
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
        adapter.setLeftJoyConOrientation(leftJoyConOrientation)
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
            Task { @MainActor [weak self] in
                self?.releaseKeyboardState(reason: "Application terminating")
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
                profile = try profileStore.reset()
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
        panel.message = "Choose a Joy-Con Codex Controller Community profile."
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            guard let profileStore else {
                throw CocoaError(.fileNoSuchFile)
            }
            let imported = try profileStore.importProfile(from: url)
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

    private func handleControllers(_ descriptors: [ControllerDescriptor]) {
        let previousActiveID = supportedControllers.first?.id
        let hadSupportedController = !supportedControllers.isEmpty
        controllers = descriptors
        let hasSupportedController = !supportedControllers.isEmpty
        let currentActiveID = supportedControllers.first?.id

        if hasSupportedController {
            if let previousActiveID, previousActiveID != currentActiveID {
                releaseKeyboardState(reason: "Active Joy-Con changed")
            }
            let names = supportedControllers.map(\.name).joined(separator: ", ")
            statusMessage = "Connected: \(names)"
            if !hadSupportedController {
                feedbackMessage = "Joy-Con connected. Visual feedback is active."
            }
        } else {
            releaseKeyboardState(reason: "Joy-Con disconnected")
            statusMessage = descriptors.isEmpty
                ? "No controllers detected. Pair a Joy-Con in macOS Bluetooth settings."
                : "No supported Joy-Con detected."
        }
    }

    private func handle(_ event: ControllerEvent) {
        recentEvent = event
        if event.phase == .released {
            stopRepeating(event.input)
        }
        if shouldConsumeForCodexFocus(event) {
            recentResult = nil
            accessibilityTrusted = AccessibilityPermission.isTrusted()
            return
        }
        if let mapping = profile.mapping(for: event.input), mapping.doubleTapAction != nil {
            handleTapSequence(event, mapping: mapping)
            return
        }

        let result = mappingEngine.process(
            event,
            profile: profile,
            testMode: testMode,
            emitter: emitter
        )
        recentResult = result
        accessibilityTrusted = AccessibilityPermission.isTrusted()

        if
            event.phase == .pressed,
            result.disposition == .emitted,
            let action = result.action,
            let plan = ControllerRepeatPolicy.plan(for: event.input, action: action)
        {
            startRepeating(event.input, plan: plan)
        }

        let actionDescription = result.functionDescription
            ?? result.action?.formatted
            ?? "Disabled"
        switch result.disposition {
        case .emitted, .coalesced, .deferred, .suppressedByTestMode, .layerActivated, .layerReleased:
            let layer = result.layer.rawValue
            feedbackMessage = "\(event.input.displayName) [\(layer)] → \(actionDescription)."
            if event.phase == .pressed, result.disposition != .layerActivated {
                feedbackMessage += " " + adapter.playConfirmation()
            }
        case .failed(let message):
            feedbackMessage = "\(event.input.displayName) blocked: \(message)"
        case .released, .repeated, .unmapped, .disabled:
            break
        }
    }

    private func shouldConsumeForCodexFocus(_ event: ControllerEvent) -> Bool {
        guard focusCodexOnStickMove, !testMode else { return false }
        guard CodexFocusTrigger.shouldFocus(for: event) else { return false }
        let activeLayer: MappingLayer = mappingEngine.isFunctionLayerActive
            ? .function
            : .primary
        if profile.mapping(for: event.input)?.action(for: activeLayer)?.kind.isScroll == true {
            return false
        }
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                != Self.codexBundleIdentifier
        else {
            return false
        }

        releaseKeyboardState(reason: "Focusing Codex")
        guard
            let codexURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: Self.codexBundleIdentifier
            )
        else {
            feedbackMessage = "Codex was not found; this first direction was consumed."
            return true
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(
            at: codexURL,
            configuration: configuration
        ) { _, _ in }
        feedbackMessage = "Stick movement focused Codex; this first direction was consumed."

        return true
    }

    private func releaseKeyboardState(reason: String) {
        stopAllRepeating()
        cancelTapSequences()
        do {
            try mappingEngine.releaseAll(emitter: emitter)
        } catch {
            feedbackMessage = "\(reason); held shortcut cleanup failed: \(error.localizedDescription)"
        }
    }

    private func startRepeating(_ input: ControllerInput, plan: RepeatPlan) {
        stopRepeating(input)
        repeatTasks[input] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: plan.initialDelayMilliseconds * 1_000_000
                )
                while !Task.isCancelled {
                    guard let self else { return }
                    try self.emit(plan.output)
                    try await Task.sleep(
                        nanoseconds: plan.intervalMilliseconds * 1_000_000
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                self.feedbackMessage = "\(input.displayName) repeat blocked: \(error.localizedDescription)"
                self.repeatTasks[input] = nil
            }
        }
    }

    private func emit(_ output: ContinuousOutput) throws {
        switch output {
        case let .keyboardTap(shortcut):
            try emitter.emit(shortcut, phase: .tap)
        case let .scroll(command):
            try emitter.emit(command)
        }
    }

    private func stopRepeating(_ input: ControllerInput) {
        repeatTasks.removeValue(forKey: input)?.cancel()
    }

    private func stopAllRepeating() {
        for task in repeatTasks.values {
            task.cancel()
        }
        repeatTasks.removeAll()
    }

    private func handleTapSequence(_ event: ControllerEvent, mapping: InputMapping) {
        let interval = mapping.resolvedDoubleTapIntervalMilliseconds
        if event.phase == .pressed,
           tapSequenceRecognizer.expire(event.input, at: event.timestamp) {
            emitPendingSingleTap(for: event.input)
        }

        switch event.phase {
        case .pressed:
            switch tapSequenceRecognizer.press(event.input, at: event.timestamp) {
            case .firstTap:
                setSequenceFeedback(
                    event: event,
                    action: mapping.primaryAction,
                    disposition: .deferred,
                    message: "single pending (\(interval) ms)"
                )
            case .secondTap:
                pendingSingleTapTasks.removeValue(forKey: event.input)?.cancel()
                pendingSingleTapEvents.removeValue(forKey: event.input)
                setSequenceFeedback(
                    event: event,
                    action: mapping.doubleTapAction,
                    disposition: .deferred,
                    message: "double detected"
                )
            case .repeated:
                recentResult = MappingResult(
                    event: event,
                    layer: .primary,
                    action: mapping.primaryAction,
                    disposition: .repeated
                )
            }

        case .released:
            switch tapSequenceRecognizer.release(
                event.input,
                at: event.timestamp,
                intervalMilliseconds: interval
            ) {
            case .singlePending:
                pendingSingleTapEvents[event.input] = event
                let input = event.input
                pendingSingleTapTasks[input]?.cancel()
                pendingSingleTapTasks[input] = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(interval))
                    guard !Task.isCancelled, let self else { return }
                    guard self.tapSequenceRecognizer.expire(input, at: .now) else { return }
                    self.emitPendingSingleTap(for: input)
                }
            case .doubleTap:
                emitSequenceAction(
                    mapping.doubleTapAction,
                    event: event,
                    label: "double"
                )
            case .ignored:
                recentResult = MappingResult(
                    event: event,
                    layer: .primary,
                    action: nil,
                    disposition: .released
                )
            }
        }
    }

    private func emitPendingSingleTap(for input: ControllerInput) {
        pendingSingleTapTasks.removeValue(forKey: input)?.cancel()
        guard
            let event = pendingSingleTapEvents.removeValue(forKey: input),
            let mapping = profile.mapping(for: input)
        else { return }
        emitSequenceAction(mapping.primaryAction, event: event, label: "single")
    }

    private func emitSequenceAction(
        _ action: MappingAction?,
        event: ControllerEvent,
        label: String
    ) {
        guard let action, action.kind == .tap, let shortcut = action.shortcut else {
            setSequenceFeedback(
                event: event,
                action: action,
                disposition: .disabled,
                message: "\(label) disabled"
            )
            return
        }
        if testMode {
            setSequenceFeedback(
                event: event,
                action: action,
                disposition: .suppressedByTestMode,
                message: "\(label) tested only"
            )
            return
        }
        do {
            try emitter.emit(shortcut, phase: .tap)
            setSequenceFeedback(
                event: event,
                action: action,
                disposition: .emitted,
                message: "\(label) sent"
            )
            feedbackMessage += " " + adapter.playConfirmation()
        } catch {
            setSequenceFeedback(
                event: event,
                action: action,
                disposition: .failed(error.localizedDescription),
                message: "\(label) blocked: \(error.localizedDescription)"
            )
        }
        accessibilityTrusted = AccessibilityPermission.isTrusted()
    }

    private func setSequenceFeedback(
        event: ControllerEvent,
        action: MappingAction?,
        disposition: MappingDisposition,
        message: String
    ) {
        let result = MappingResult(
            event: event,
            layer: .primary,
            action: action,
            disposition: disposition
        )
        recentResult = result
        let actionDescription = result.functionDescription
            ?? action?.formatted
            ?? "Disabled"
        feedbackMessage = "\(event.input.displayName) [Default] → \(actionDescription) · \(message)."
    }

    private func cancelTapSequences() {
        for task in pendingSingleTapTasks.values {
            task.cancel()
        }
        pendingSingleTapTasks.removeAll()
        pendingSingleTapEvents.removeAll()
        tapSequenceRecognizer.reset()
    }
}
