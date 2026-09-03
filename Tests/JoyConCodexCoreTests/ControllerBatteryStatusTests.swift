import Testing
@testable import JoyConCodexCore

@Suite("Controller battery display")
struct ControllerBatteryStatusTests {
    @Test("Battery levels are rounded and formatted")
    func percentageFormatting() {
        let status = ControllerBatteryStatus(
            level: 0.684,
            chargeState: .discharging
        )

        #expect(status.levelPercent == 68)
        #expect(status.compactSummary == "68%")
        #expect(status.summary == "68% · On battery")
        #expect(status.systemImage == "battery.75")
    }

    @Test("Battery levels are clamped to the documented range")
    func clamping() {
        #expect(
            ControllerBatteryStatus(level: -0.5, chargeState: .unknown).levelPercent == 0
        )
        #expect(
            ControllerBatteryStatus(level: 1.4, chargeState: .full).levelPercent == 100
        )
    }

    @Test("Charging status uses the charging symbol")
    func chargingSymbol() {
        let status = ControllerBatteryStatus(level: 0.4, chargeState: .charging)

        #expect(status.summary == "40% · Charging")
        #expect(status.systemImage == "battery.100.bolt")
    }

    @Test("Raw Joy-Con levels are visibly approximate")
    func rawJoyConFormatting() {
        let status = ControllerBatteryStatus(rawJoyConLevel: 3, charging: false)

        #expect(status?.levelPercent == 75)
        #expect(status?.rawLevelName == "High")
        #expect(status?.compactSummary == "≈75%")
        #expect(status?.summary == "High (≈75%) · On battery · Joy-Con HID")
        #expect(status?.source == .joyConHID)
    }
}
