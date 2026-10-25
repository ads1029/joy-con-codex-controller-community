import Testing
@testable import JoyConCodexCore

@Suite("Electron accessibility readiness")
@MainActor
struct DesktopAccessibilityReadinessTests {
    @Test("Request web accessibility before inspecting page controls and retry an empty shell")
    func delayedWebTree() async throws {
        var enabled = false, checks = 0, pauses = 0
        let ready = try await DesktopAccessibilityReadiness.prepare(attempts: 4, enable: {
            enabled = true
        }, isReady: {
            #expect(enabled)
            checks += 1
            return checks == 3
        }, pause: { pauses += 1 })
        #expect(ready)
        #expect(checks == 3)
        #expect(pauses == 2)
    }

    @Test("An unavailable web tree times out instead of authorizing page actions")
    func unavailableWebTree() async throws {
        var checks = 0, pauses = 0
        let ready = try await DesktopAccessibilityReadiness.prepare(attempts: 3, enable: {}, isReady: {
            checks += 1
            return false
        }, pause: { pauses += 1 })
        #expect(!ready)
        #expect(checks == 3)
        #expect(pauses == 2)
    }

    @Test("An already exposed tree needs no delay")
    func alreadyReady() async throws {
        var pauses = 0
        let ready = try await DesktopAccessibilityReadiness.prepare(enable: {}, isReady: { true }, pause: { pauses += 1 })
        #expect(ready)
        #expect(pauses == 0)
    }
}
