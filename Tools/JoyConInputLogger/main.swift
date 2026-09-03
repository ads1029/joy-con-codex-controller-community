import Foundation
import IOKit.hid

private let nintendoVendorID = 0x057E
private let buttonUsagePage: UInt32 = 0x09

private enum JoyConKind {
    case left
    case right

    var productID: Int {
        switch self {
        case .left: 0x2006
        case .right: 0x2007
        }
    }

    var displayName: String {
        switch self {
        case .left: "Joy-Con (L)"
        case .right: "Joy-Con (R)"
        }
    }

    var guidedButtons: [String] {
        switch self {
        case .left:
            ["Up", "Down", "Left", "Right", "-", "CAPTURE", "L", "ZL", "Left Stick Click", "SL", "SR"]
        case .right:
            ["A", "B", "X", "Y", "+", "HOME", "R", "ZR", "Right Stick Click", "SL", "SR"]
        }
    }
}

private final class JoyConEventLogger {
    private let startedAt = Date()
    private let guidedButtons: [String]

    private var guidedIndex = 0
    private var eventIndex = 0
    private var pressedUsages = Set<UInt32>()
    private var guidedResults: [(button: String, usage: UInt32)] = []

    init(kind: JoyConKind) {
        guidedButtons = kind.guidedButtons
    }

    func deviceMatched(_ device: IOHIDDevice) {
        let product = property(kIOHIDProductKey, from: device) as? String ?? "Unknown"
        let vendorID = property(kIOHIDVendorIDKey, from: device) as? Int ?? 0
        let productID = property(kIOHIDProductIDKey, from: device) as? Int ?? 0

        write(
            "DEVICE product=\(quoted(product)) vendor=\(hex(vendorID)) "
                + "productID=\(hex(productID))"
        )
        write("")
        writeCurrentPrompt()
    }

    func deviceRemoved(_ device: IOHIDDevice) {
        let product = property(kIOHIDProductKey, from: device) as? String ?? "Unknown"
        write("DEVICE_REMOVED product=\(quoted(product))")
    }

    func received(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)

        guard page == buttonUsagePage else { return }

        eventIndex += 1
        let state = integerValue == 0 ? "released" : "pressed"
        write(
            "EVENT index=\(eventIndex) elapsed=\(elapsed()) "
                + "page=\(hex(page)) usage=\(usage) value=\(integerValue) state=\(state)"
        )

        if integerValue == 0 {
            pressedUsages.remove(usage)
            return
        }

        guard pressedUsages.insert(usage).inserted else { return }
        guard guidedIndex < guidedButtons.count else { return }

        let physicalButton = guidedButtons[guidedIndex]
        guidedResults.append((physicalButton, usage))
        write("MATCH physical=\(quoted(physicalButton)) hidUsage=\(usage)")
        guidedIndex += 1

        if guidedIndex < guidedButtons.count {
            writeCurrentPrompt()
        } else {
            writeSummary()
        }
    }

    private func writeCurrentPrompt() {
        guard guidedIndex < guidedButtons.count else { return }
        write("PROMPT Release all controls, then press physical [\(guidedButtons[guidedIndex])] once.")
    }

    private func writeSummary() {
        write("")
        write("GUIDED_TEST_COMPLETE")
        for result in guidedResults {
            write("SUMMARY physical=\(quoted(result.button)) hidUsage=\(result.usage)")
        }
        write("")
        write("The logger will keep printing button events. Press Control-C to stop.")
    }

    private func elapsed() -> String {
        String(format: "%.3fs", Date().timeIntervalSince(startedAt))
    }

    private func property(_ key: String, from device: IOHIDDevice) -> Any? {
        IOHIDDeviceGetProperty(device, key as CFString)
    }

    private func hex(_ value: some BinaryInteger) -> String {
        String(format: "0x%X", Int(value))
    }

    private func quoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
    }

    private func write(_ line: String) {
        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }
}

private func logger(
    from context: UnsafeMutableRawPointer?
) -> JoyConEventLogger? {
    guard let context else { return nil }
    return Unmanaged<JoyConEventLogger>.fromOpaque(context).takeUnretainedValue()
}

private func deviceMatchedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess else { return }
    logger(from: context)?.deviceMatched(device)
}

private func deviceRemovedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess else { return }
    logger(from: context)?.deviceRemoved(device)
}

private func inputValueCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard result == kIOReturnSuccess else { return }
    logger(from: context)?.received(value)
}

@main
private enum JoyConInputLoggerMain {
    static func main() {
        let kind: JoyConKind = CommandLine.arguments.contains("--right") ? .right : .left
        let eventLogger = JoyConEventLogger(kind: kind)
        let context = Unmanaged.passUnretained(eventLogger).toOpaque()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: nintendoVendorID,
            kIOHIDProductIDKey: kind.productID,
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            deviceMatchedCallback,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            deviceRemovedCallback,
            context
        )
        IOHIDManagerRegisterInputValueCallback(
            manager,
            inputValueCallback,
            context
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetCurrent(),
            CFRunLoopMode.defaultMode.rawValue
        )

        FileHandle.standardOutput.write(
            Data(
                (
                    "\(kind.displayName) HID logger\n"
                        + "Listening for Nintendo 0x057E / \(kind.displayName) "
                        + String(format: "0x%04X", kind.productID) + ".\n"
                        + "Use --right to inspect a right Joy-Con; left is the default.\n"
                        + "Keep every control released until its prompt appears.\n\n"
                ).utf8
            )
        )

        let openResult = IOHIDManagerOpen(
            manager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        guard openResult == kIOReturnSuccess else {
            FileHandle.standardError.write(
                Data("Could not open IOHIDManager: \(openResult)\n".utf8)
            )
            Foundation.exit(EXIT_FAILURE)
        }

        CFRunLoopRun()
    }
}
