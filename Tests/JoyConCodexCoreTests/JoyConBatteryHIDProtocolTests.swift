import Testing
@testable import JoyConCodexCore

@Suite("Joy-Con raw battery protocol")
struct JoyConBatteryHIDProtocolTests {
    @Test("State request uses neutral rumble data and a no-op subcommand")
    func stateRequest() {
        #expect(
            JoyConBatteryHIDProtocol.makeStateRequest(packetNumber: 0x23) == [
                0x01, 0x03,
                0x00, 0x01, 0x40, 0x40,
                0x00, 0x01, 0x40, 0x40,
                0x00,
            ]
        )
    }

    @Test("Captured left Joy-Con reply decodes as high battery")
    func capturedReply() {
        let bytes: [UInt8] = [
            0x21, 0x15, 0x6E, 0x00, 0x00, 0x00, 0xD4, 0x27,
            0x8F, 0x00, 0x00, 0x00, 0xA0, 0x80, 0x00, 0x03,
        ]
        let status = JoyConBatteryHIDProtocol.parseBatteryStatus(
            reportID: 0x21,
            bytes: bytes
        )

        #expect(status?.rawJoyConLevel == 3)
        #expect(status?.levelPercent == 75)
        #expect(status?.chargeState == .discharging)
    }

    @Test("Parser accepts callbacks whose buffer omits the report ID")
    func reportIDOutsideBuffer() {
        let status = JoyConBatteryHIDProtocol.parseBatteryStatus(
            reportID: 0x21,
            bytes: [0x15, 0x50]
        )

        #expect(status?.rawJoyConLevel == 2)
        #expect(status?.chargeState == .charging)
    }

    @Test("Compatibility reports and invalid levels are ignored")
    func invalidReports() {
        #expect(
            JoyConBatteryHIDProtocol.parseBatteryStatus(
                reportID: 0x3F,
                bytes: [0x3F, 0x00, 0x6E]
            ) == nil
        )
        #expect(
            JoyConBatteryHIDProtocol.parseBatteryStatus(
                reportID: 0x21,
                bytes: [0x21, 0x00, 0xAE]
            ) == nil
        )
    }
}
