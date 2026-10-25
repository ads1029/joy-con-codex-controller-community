import AppKit
import ApplicationServices
import Darwin
import JoyConCodexCore

/// Experimental Spaces bridge. Resolve symbols at runtime, and verify every move.
/// No Dock injection, elevated helper or change to System Integrity Protection.
@MainActor
private final class SpacesBridge {
    struct Space {
        let id: UInt64
        let uuid: String
        let display: String
        let number: Int
        let type: Int
    }
    private let handle: UnsafeMutableRawPointer
    private let connection: Int32
    private let copyDisplays: @convention(c) (Int32) -> Unmanaged<CFArray>?
    private let copyWindowSpaces: @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private let setCompat: @convention(c) (Int32, UInt64, Int32) -> Int32
    private let setWorkspace: @convention(c) (Int32, UnsafePointer<UInt32>, Int32, Int32) -> Int32
    private let windowID: @convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> AXError

    init() throws {
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 14, minorVersion: 5, patchVersion: 0)) else {
            throw DesktopControlError.unavailable("Desktop restoration requires macOS 14.5 or later.")
        }
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY) else {
            throw DesktopControlError.unavailable("Spaces interface is unavailable.")
        }
        self.handle = handle
        func symbol<T>(_ name: String, _: T.Type) throws -> T {
            guard let pointer = dlsym(handle, name) else {
                throw DesktopControlError.unavailable("Spaces interface missing: \(name)")
            }
            return unsafeBitCast(pointer, to: T.self)
        }
        let main = try symbol("SLSMainConnectionID", (@convention(c) () -> Int32).self)
        connection = main()
        copyDisplays = try symbol("SLSCopyManagedDisplaySpaces", (@convention(c) (Int32) -> Unmanaged<CFArray>?).self)
        copyWindowSpaces = try symbol("SLSCopySpacesForWindows", (@convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?).self)
        setCompat = try symbol("SLSSpaceSetCompatID", (@convention(c) (Int32, UInt64, Int32) -> Int32).self)
        setWorkspace = try symbol("SLSSetWindowListWorkspace", (@convention(c) (Int32, UnsafePointer<UInt32>, Int32, Int32) -> Int32).self)
        guard let axSymbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else {
            throw DesktopControlError.unavailable("Window identity interface is unavailable.")
        }
        windowID = unsafeBitCast(axSymbol, to: (@convention(c) (AXUIElement, UnsafeMutablePointer<UInt32>) -> AXError).self)
    }

    func spaces() throws -> [Space] {
        guard let raw = copyDisplays(connection)?.takeRetainedValue() as? [[String: Any]] else {
            throw DesktopControlError.unavailable("Could not read desktop identities.")
        }
        var result: [Space] = []
        var number = 0
        for display in raw {
            guard let displayID = display["Display Identifier"] as? String,
                  let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            for space in spaces {
                guard let id = space["id64"] as? NSNumber, let uuid = space["uuid"] as? String,
                      let type = space["type"] as? Int else { continue }
                if type == 0 { number += 1 }
                result.append(Space(id: id.uint64Value, uuid: uuid, display: displayID, number: number, type: type))
            }
        }
        guard !result.isEmpty else { throw DesktopControlError.unavailable("No managed desktops found.") }
        return result
    }

    func id(of window: AXUIElement) throws -> UInt32 {
        var id: UInt32 = 0
        guard windowID(window, &id) == .success, id != 0 else {
            throw DesktopControlError.unavailable("Could not identify the application window.")
        }
        return id
    }

    func spaces(for window: UInt32) -> [UInt64] {
        let windows = [NSNumber(value: window)] as CFArray
        return (copyWindowSpaces(connection, 7, windows)?.takeRetainedValue() as? [NSNumber])?.map(\.uint64Value) ?? []
    }

    func move(_ window: UInt32, to space: Space) throws {
        if spaces(for: window) == [space.id] { return }
        guard space.type == 0 else { throw DesktopControlError.unavailable("Only ordinary desktops can be restored.") }
        // Compatibility workspace technique used by Hammerspoon on macOS 14.5+.
        // Always clear the temporary compatibility ID, including on failure.
        let tag: Int32 = 0x796a6375
        guard setCompat(connection, space.id, tag) == 0 else {
            throw DesktopControlError.unavailable("macOS rejected the desktop move.")
        }
        defer { _ = setCompat(connection, space.id, 0) }
        var id = window
        guard setWorkspace(connection, &id, 1, tag) == 0 else {
            throw DesktopControlError.unavailable("macOS rejected the window move.")
        }
    }
}

struct DesktopLayoutCandidate: Identifiable {
    let target: DesktopTarget
    let identity: DesktopWindowIdentity
    let desktopNumber: Int
    let frame: CGRect
    var id: DesktopWindowIdentity { identity }
    var label: String {
        "桌面 \(desktopNumber) · \(Int(frame.width))×\(Int(frame.height)) · 位置 \(Int(frame.minX)),\(Int(frame.minY)) · 窗口 \(identity.windowID)"
    }
}

@MainActor
final class DesktopLayoutController {
    private struct WindowMetadata {
        let application: NSRunningApplication
        let id: UInt32
        let frame: CGRect
    }
    private struct Placement: Codable {
        let target: DesktopTarget
        let spaceUUID: String
        let displayUUID: String
        let desktopNumber: Int
        let frame: CGRect
        let identity: DesktopWindowIdentity?
    }
    private let defaults: UserDefaults?
    private let key = "codingDesktopLayout.v1"
    private var bridge: SpacesBridge?

    init(defaults: UserDefaults?) { self.defaults = defaults }

    var summary: String {
        guard let saved = try? load() else { return "尚未记录 Codex / Claude 的桌面位置" }
        return saved.map { "\($0.target.displayName) · 桌面 \($0.desktopNumber)" }.joined(separator: "；")
    }

    private func api() throws -> SpacesBridge {
        if let bridge { return bridge }
        let created = try SpacesBridge()
        bridge = created
        return created
    }

    private func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    /// WindowServer includes windows on inactive desktops, unlike AXWindows.
    /// Only identity/geometry is read, never titles or application contents.
    private func metadata(_ target: DesktopTarget) throws -> [WindowMetadata] {
        guard AXIsProcessTrusted() else { throw DesktopControlError.unavailable("Accessibility permission is required to record or restore windows.") }
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleIdentifier)
        guard apps.count == 1, let app = apps.first else {
            throw DesktopControlError.unavailable("Open one instance of \(target.displayName) before recording/restoring.")
        }
        let entries = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let windows = entries.compactMap { entry -> WindowMetadata? in
            guard (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == app.processIdentifier,
                  (entry[kCGWindowLayer as String] as? Int) == 0,
                  let id = entry[kCGWindowNumber as String] as? NSNumber,
                  let bounds = entry[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width >= 200, rect.height >= 120,
                  (entry[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
            return WindowMetadata(application: app, id: id.uint32Value, frame: rect)
        }
        guard !windows.isEmpty else {
            throw DesktopControlError.unavailable("\(target.displayName) has no available ordinary window.")
        }
        return windows
    }

    private func identity(_ window: WindowMetadata) -> DesktopWindowIdentity {
        DesktopWindowIdentity(processID: window.application.processIdentifier, windowID: window.id)
    }

    func candidates() throws -> [DesktopLayoutCandidate] {
        let bridge = try api(), spaces = try bridge.spaces()
        return try DesktopTarget.allCases.flatMap { target in
            let choices = try metadata(target).compactMap { window -> DesktopLayoutCandidate? in
                let memberships = bridge.spaces(for: window.id)
                guard memberships.count == 1,
                      let space = spaces.first(where: { $0.id == memberships[0] && $0.type == 0 }) else { return nil }
                return DesktopLayoutCandidate(target: target, identity: identity(window),
                                              desktopNumber: space.number, frame: window.frame)
            }
            guard !choices.isEmpty else {
                throw DesktopControlError.unavailable("\(target.displayName) has no window on a single ordinary desktop. Exit fullscreen first.")
            }
            return choices.sorted {
                if $0.desktopNumber != $1.desktopNumber { return $0.desktopNumber < $1.desktopNumber }
                return $0.identity.windowID < $1.identity.windowID
            }
        }
    }

    private func accessibleWindow(_ metadata: WindowMetadata) throws -> AXUIElement? {
        let application = AXUIElementCreateApplication(metadata.application.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 1)
        let bridge = try api()
        let windows = value(application, kAXWindowsAttribute) as? [AXUIElement] ?? []
        guard let window = windows.first(where: { (try? bridge.id(of: $0)) == metadata.id }) else { return nil }
        guard (value(window, kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole else {
            throw DesktopControlError.unavailable("The target is not a standard application window.")
        }
        guard (value(window, "AXFullScreen") as? Bool) != true,
              (value(window, kAXMinimizedAttribute) as? Bool) != true else {
            throw DesktopControlError.unavailable("Exit fullscreen and unminimize the target app first.")
        }
        return window
    }

    private func frame(_ window: AXUIElement) throws -> CGRect {
        guard let p = value(window, kAXPositionAttribute), CFGetTypeID(p) == AXValueGetTypeID(),
              let s = value(window, kAXSizeAttribute), CFGetTypeID(s) == AXValueGetTypeID() else {
            throw DesktopControlError.unavailable("Window geometry is unavailable.")
        }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else {
            throw DesktopControlError.unavailable("Window geometry could not be decoded.")
        }
        return CGRect(origin: point, size: size)
    }

    func capture(selections: [DesktopTarget: DesktopWindowIdentity]) throws {
        guard let defaults else { throw DesktopControlError.unavailable("Preferences are unavailable; layout was not saved.") }
        let bridge = try api(), spaces = try bridge.spaces()
        let placements = try DesktopTarget.allCases.map { target in
            let windows = try metadata(target)
            guard let selection = selections[target],
                  let window = windows.first(where: { identity($0) == selection }) else {
                throw DesktopControlError.unavailable("Select the intended \(target.displayName) window, then record again.")
            }
            let memberships = bridge.spaces(for: window.id)
            guard memberships.count == 1, let space = spaces.first(where: { $0.id == memberships[0] }), space.type == 0 else {
                throw DesktopControlError.unavailable("\(target.displayName) must belong to one ordinary desktop.")
            }
            return Placement(target: target, spaceUUID: space.uuid, displayUUID: space.display,
                             desktopNumber: space.number, frame: window.frame, identity: identity(window))
        }
        defaults.set(try JSONEncoder().encode(placements), forKey: key)
    }

    private func load() throws -> [Placement] {
        guard let data = defaults?.data(forKey: key) else { throw DesktopControlError.unavailable("Record the desktop layout first.") }
        let saved = try JSONDecoder().decode([Placement].self, from: data)
        guard Set(saved.map(\.target)) == Set(DesktopTarget.allCases), saved.count == 2 else {
            throw DesktopControlError.unavailable("Saved desktop layout is incomplete; record it again.")
        }
        return saved
    }

    func restore() async throws {
        let bridge = try api(), spaces = try bridge.spaces()
        // Validate BOTH destinations/windows before making any change.
        let plan = try load().map { placement -> (Placement, WindowMetadata, SpacesBridge.Space) in
            guard let space = spaces.first(where: { $0.uuid == placement.spaceUUID && $0.display == placement.displayUUID }), space.type == 0 else {
                throw DesktopControlError.unavailable("Saved desktop for \(placement.target.displayName) no longer exists; record the layout again.")
            }
            let windows = try metadata(placement.target)
            guard let match = DesktopWindowMatching.resolve(saved: placement.identity, current: windows.map(identity)),
                  let window = windows.first(where: { identity($0) == match }) else {
                throw DesktopControlError.unavailable("\(placement.target.displayName)'s recorded window is missing or ambiguous. Select its window and record again.")
            }
            let memberships = bridge.spaces(for: window.id)
            guard memberships.count == 1, spaces.contains(where: { $0.id == memberships[0] && $0.type == 0 }) else {
                throw DesktopControlError.unavailable("\(placement.target.displayName) is not on one ordinary desktop.")
            }
            guard !placement.frame.isEmpty, !placement.frame.isInfinite, !placement.frame.isNull else {
                throw DesktopControlError.unavailable("Saved window geometry is invalid.")
            }
            return (placement, window, space)
        }
        let previous = NSWorkspace.shared.frontmostApplication
        var activated = false
        defer { if activated { previous?.activate(options: []) } }
        // Resolve both AX handles before the first move. AXWindows may be empty
        // off-Space; briefly activate only when needed, then restore prior focus.
        var resolved: [(Placement, AXUIElement, UInt32, SpacesBridge.Space)] = []
        for (placement, metadata, space) in plan {
            try Task.checkCancellation()
            var window = try accessibleWindow(metadata)
            if window == nil {
                guard metadata.application.activate(options: []) else {
                    throw DesktopControlError.unavailable("Could not activate \(placement.target.displayName) to restore its window.")
                }
                activated = true
                for _ in 0..<20 {
                    try await Task.sleep(for: .milliseconds(75))
                    window = try accessibleWindow(metadata)
                    if window != nil { break }
                }
            }
            guard let window else {
                throw DesktopControlError.unavailable("\(placement.target.displayName) did not expose its window for restoration.")
            }
            resolved.append((placement, window, metadata.id, space))
        }
        for (placement, window, id, space) in resolved {
            try Task.checkCancellation()
            try bridge.move(id, to: space)
            var verified = false
            for _ in 0..<10 {
                if bridge.spaces(for: id) == [space.id] { verified = true; break }
                try await Task.sleep(for: .milliseconds(50))
            }
            guard verified else { throw DesktopControlError.unavailable("macOS did not move \(placement.target.displayName); desktop restore is incomplete.") }
            var point = placement.frame.origin, size = placement.frame.size
            guard let position = AXValueCreate(.cgPoint, &point), let dimensions = AXValueCreate(.cgSize, &size),
                  AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions) == .success,
                  AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position) == .success else {
                throw DesktopControlError.unavailable("\(placement.target.displayName) rejected the saved window geometry.")
            }
            let restored = try frame(window)
            guard abs(restored.minX - point.x) <= 3, abs(restored.minY - point.y) <= 3,
                  abs(restored.width - size.width) <= 3, abs(restored.height - size.height) <= 3 else {
                throw DesktopControlError.unavailable("\(placement.target.displayName) window geometry did not match the saved layout.")
            }
            guard bridge.spaces(for: id) == [space.id] else {
                throw DesktopControlError.unavailable("\(placement.target.displayName) changed desktops while restoring its geometry.")
            }
        }
    }
}
