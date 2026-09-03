public enum LeftJoyConHIDMapping {
    public static let vendorID = 0x057E
    public static let productID = 0x2006
    public static let buttonUsagePage: UInt32 = 0x09

    /// GameController exposes the rail buttons as its two generic shoulders.
    /// Raw usages 15/16 supplement the top L/ZL buttons that are absent from
    /// that micro-gamepad profile. Raw usages 5/6 are the same SL/SR presses
    /// already delivered by GameController and must stay ignored.
    public static func input(forButtonUsage usage: UInt32) -> ControllerInput? {
        switch usage {
        case 15: .leftShoulder
        case 16: .leftTrigger
        default: nil
        }
    }

    public static func isGameControllerOwnedDuplicate(_ usage: UInt32) -> Bool {
        usage == 5 || usage == 6
    }
}
