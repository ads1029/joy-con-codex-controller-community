import Testing
@testable import JoyConCodexCore

@Suite("Desktop window identity")
struct DesktopWindowMatchingTests {
    private let selected = DesktopWindowIdentity(processID: 10, windowID: 42)

    @Test("Four open windows restore only the explicitly recorded window")
    func multipleWindows() {
        let current = [40, 41, 42, 43].map { DesktopWindowIdentity(processID: 10, windowID: UInt32($0)) }
        #expect(DesktopWindowMatching.resolve(saved: selected, current: current) == selected)
    }

    @Test("Closing the recorded window never substitutes another in the same app")
    func closedWindow() {
        let other = DesktopWindowIdentity(processID: 10, windowID: 43)
        #expect(DesktopWindowMatching.resolve(saved: selected, current: [other]) == nil)
    }

    @Test("A restarted app can match one window but cannot guess between several")
    func restartedApp() {
        let first = DesktopWindowIdentity(processID: 20, windowID: 80)
        let second = DesktopWindowIdentity(processID: 20, windowID: 81)
        #expect(DesktopWindowMatching.resolve(saved: selected, current: [first]) == first)
        #expect(DesktopWindowMatching.resolve(saved: selected, current: [first, second]) == nil)
    }

    @Test("Old snapshots and empty candidates fail safely when ambiguous")
    func missingIdentity() {
        #expect(DesktopWindowMatching.resolve(saved: nil, current: []) == nil)
        #expect(DesktopWindowMatching.resolve(saved: nil, current: [selected]) == selected)
        #expect(DesktopWindowMatching.resolve(saved: nil, current: [selected, .init(processID: 10, windowID: 43)]) == nil)
    }
}
