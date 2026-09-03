public enum JoyConBatteryHIDProtocol {
    public static let outputReportID: UInt8 = 0x01
    public static let getControllerStateSubcommand: UInt8 = 0x00

    private static let batteryReportIDs: Set<UInt8> = [
        0x21, 0x30, 0x31, 0x32, 0x33,
    ]

    public static func makeStateRequest(packetNumber: UInt8) -> [UInt8] {
        [
            outputReportID,
            packetNumber & 0x0F,
            0x00, 0x01, 0x40, 0x40,
            0x00, 0x01, 0x40, 0x40,
            getControllerStateSubcommand,
        ]
    }

    public static func parseBatteryStatus(
        reportID: UInt32,
        bytes: [UInt8]
    ) -> ControllerBatteryStatus? {
        guard let declaredReportID = UInt8(exactly: reportID) else { return nil }
        let includesReportID = bytes.first == declaredReportID
        let packetID = includesReportID ? bytes[0] : declaredReportID
        guard batteryReportIDs.contains(packetID) else { return nil }

        let batteryIndex = includesReportID ? 2 : 1
        guard bytes.indices.contains(batteryIndex) else { return nil }

        let batteryAndConnection = bytes[batteryIndex]
        let rawLevel = (batteryAndConnection >> 5) & 0x07
        let charging = batteryAndConnection & 0x10 != 0
        return ControllerBatteryStatus(
            rawJoyConLevel: rawLevel,
            charging: charging
        )
    }
}
