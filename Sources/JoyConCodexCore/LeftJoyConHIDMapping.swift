public enum LeftJoyConHIDMapping {
    public static let vendorID = 0x057E
    public static let productID = 0x2006
    public static let buttonUsagePage: UInt32 = 0x09

    /// GameController exposes the rail buttons as its two generic shoulders.
    /// Raw usage 11 supplements the stick click; usages 15/16 supplement L/ZL absent from
    /// that micro-gamepad profile. Raw usages 5/6 are the same SL/SR presses
    /// already delivered by GameController and must stay ignored.
    public static func input(forButtonUsage usage: UInt32) -> ControllerInput? {
        switch usage {
        case 11: .leftStickPress
        case 15: .leftShoulder
        case 16: .leftTrigger
        default: nil
        }
    }

    public static func isGameControllerOwnedDuplicate(_ usage: UInt32) -> Bool {
        usage == 5 || usage == 6
    }
}

extension LeftJoyConHIDMapping {
    /// macOS can deliver 0x30 full reports without producing button IOHIDValues
    /// for usages 15/16. Parse only the three missing controls; GameController
    /// still owns D-pad, stick directions, and SL/SR.
    ///
    /// IOHID input-report callbacks on this host include the report ID.
    /// Headerless callers must opt in explicitly so a timer byte equal to the
    /// report ID is never mistaken for an additional header.
    public static func inputs(reportID: UInt32, bytes: [UInt8],
        includesReportID: Bool = true) -> Set<ControllerInput>? {
        guard let id = UInt8(exactly: reportID) else { return nil }
        let offset = includesReportID ? 1 : 0
        if includesReportID, bytes.first != id { return nil }
        let shoulder: UInt8
        let stickDown: Bool
        switch id {
        case 0x30, 0x31, 0x32, 0x33:
            guard bytes.count >= offset + 12 else { return nil }
            shoulder = bytes[offset + 4]   // left button bank
            stickDown = bytes[offset + 3] & 0x08 != 0
        case 0x3f:
            guard bytes.count >= offset + 11 else { return nil }
            shoulder = bytes[offset + 1]
            stickDown = bytes[offset + 1] & 0x04 != 0
        default:
            // 0x21 replies are battery/command snapshots, not the streaming
            // button authority. A late reply must not release a held L/ZL.
            return nil
        }
        var result = Set<ControllerInput>()
        if shoulder & 0x40 != 0 { result.insert(.leftShoulder) }
        if shoulder & 0x80 != 0 { result.insert(.leftTrigger) }
        if stickDown { result.insert(.leftStickPress) }
        return result
    }
}

/// Merge the report stream and the legacy HID-value path as one edge source.
/// Once a valid report arrives, stale/duplicate element callbacks cannot
/// interrupt it. Reconnect resets this authority and releases any held inputs.
public struct LeftJoyConSupplementState: Sendable {
    public private(set) var held = Set<ControllerInput>()
    public private(set) var usesReportInput = false
    private let order: [ControllerInput] = [.leftTrigger, .leftShoulder, .leftStickPress]

    public init() {}

    public mutating func processReport(reportID: UInt32, bytes: [UInt8],
        includesReportID: Bool = true) -> [ControllerEvent]? {
        guard let inputs = LeftJoyConHIDMapping.inputs(reportID: reportID, bytes: bytes,
            includesReportID: includesReportID) else { return nil }
        usesReportInput = true
        return transition(to: inputs)
    }

    public mutating func processUsage(_ usage: UInt32, value: Int) -> [ControllerEvent] {
        guard !usesReportInput, let input = LeftJoyConHIDMapping.input(forButtonUsage: usage) else { return [] }
        var next = held
        if value == 0 { next.remove(input) } else { next.insert(input) }
        return transition(to: next)
    }

    public mutating func reset() -> [ControllerEvent] {
        let result = transition(to: [])
        usesReportInput = false
        return result
    }

    private mutating func transition(to next: Set<ControllerInput>) -> [ControllerEvent] {
        // Fn enters before other presses, but exits after their releases.
        let up = order.reversed().filter { held.contains($0) && !next.contains($0) }
            .map { ControllerEvent(input: $0, phase: .released) }
        let down = order.filter { !held.contains($0) && next.contains($0) }
            .map { ControllerEvent(input: $0, phase: .pressed) }
        held = next
        return up + down
    }
}
