public enum ControllerBatteryChargeState: String, Equatable, Sendable {
    case unknown
    case discharging
    case charging
    case full

    public var displayName: String {
        switch self {
        case .unknown:
            "State unknown"
        case .discharging:
            "On battery"
        case .charging:
            "Charging"
        case .full:
            "Fully charged"
        }
    }
}

public enum ControllerBatterySource: String, Equatable, Sendable {
    case gameController
    case joyConHID

    public var displayName: String {
        switch self {
        case .gameController:
            "macOS"
        case .joyConHID:
            "Joy-Con HID"
        }
    }
}

public struct ControllerBatteryStatus: Equatable, Sendable {
    public let levelPercent: Int
    public let chargeState: ControllerBatteryChargeState
    public let source: ControllerBatterySource
    public let rawJoyConLevel: UInt8?

    public init(
        level: Float,
        chargeState: ControllerBatteryChargeState,
        source: ControllerBatterySource = .gameController,
        rawJoyConLevel: UInt8? = nil
    ) {
        let normalizedLevel = min(max(level, 0), 1)
        self.levelPercent = Int((normalizedLevel * 100).rounded())
        self.chargeState = chargeState
        self.source = source
        self.rawJoyConLevel = rawJoyConLevel
    }

    public init?(rawJoyConLevel: UInt8, charging: Bool) {
        guard rawJoyConLevel <= 4 else { return nil }
        self.init(
            level: Float(rawJoyConLevel) / 4,
            chargeState: charging ? .charging : .discharging,
            source: .joyConHID,
            rawJoyConLevel: rawJoyConLevel
        )
    }

    public var summary: String {
        if source == .joyConHID {
            return "\(rawLevelName) (≈\(levelPercent)%) · \(chargeState.displayName) · \(source.displayName)"
        }
        return "\(levelPercent)% · \(chargeState.displayName)"
    }

    public var compactSummary: String {
        source == .joyConHID ? "≈\(levelPercent)%" : "\(levelPercent)%"
    }

    public var rawLevelName: String {
        switch rawJoyConLevel {
        case 0: "Critical"
        case 1: "Low"
        case 2: "Medium"
        case 3: "High"
        case 4: "Full"
        default: "Unknown"
        }
    }

    public var systemImage: String {
        if chargeState == .charging {
            return "battery.100.bolt"
        }

        return switch levelPercent {
        case ...10:
            "battery.0"
        case ...37:
            "battery.25"
        case ...62:
            "battery.50"
        case ...87:
            "battery.75"
        default:
            "battery.100"
        }
    }
}
