import Foundation
import IOKit.hid
import JoyConCodexCore

enum LeftJoyConHIDError: LocalizedError {
    case openFailed(IOReturn)
    case mainRunLoopUnavailable

    var errorDescription: String? {
        switch self {
        case let .openFailed(result):
            let code = String(format: "0x%08X", UInt32(bitPattern: result))
            return "Could not open the left Joy-Con HID supplement (\(code))."
        case .mainRunLoopUnavailable:
            return "The main run loop is unavailable for left Joy-Con input."
        }
    }
}

/// Merges the L/ZL shoulder controls and L3 stick click that are missing from Apple's single-left
/// Joy-Con GameController profile. The rail SL/SR controls stay on the
/// GameController path, preventing a physical press from being emitted twice.
final class LeftJoyConHIDAdapter {
    var onEvent: ((ControllerEvent) -> Void)?
    var onStatus: ((String) -> Void)?
    var onBatteryStatus: ((ControllerBatteryStatus?) -> Void)?

    private var manager: IOHIDManager?
    private var activeDevice: IOHIDDevice?
    private var scheduledRunLoop: CFRunLoop?
    private var pressedUsages = Set<UInt32>()
    private var packetNumber: UInt8 = 0
    private var lastBatteryQueryAt: Date?

    var isRunning: Bool { manager != nil }

    func start() throws {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: LeftJoyConHIDMapping.vendorID,
            kIOHIDProductIDKey: LeftJoyConHIDMapping.productID,
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let runLoop = CFRunLoopGetMain() else {
            throw LeftJoyConHIDError.mainRunLoopUnavailable
        }

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            leftJoyConMatchedCallback,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            leftJoyConRemovedCallback,
            context
        )
        IOHIDManagerRegisterInputValueCallback(
            manager,
            leftJoyConInputCallback,
            context
        )
        IOHIDManagerRegisterInputReportCallback(
            manager,
            leftJoyConInputReportCallback,
            context
        )
        IOHIDManagerScheduleWithRunLoop(
            manager,
            runLoop,
            CFRunLoopMode.defaultMode.rawValue
        )

        let result = IOHIDManagerOpen(
            manager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                runLoop,
                CFRunLoopMode.defaultMode.rawValue
            )
            throw LeftJoyConHIDError.openFailed(result)
        }

        self.manager = manager
        scheduledRunLoop = runLoop
    }

    func stop() {
        guard let manager else { return }
        if let scheduledRunLoop {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                scheduledRunLoop,
                CFRunLoopMode.defaultMode.rawValue
            )
        }
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        activeDevice = nil
        scheduledRunLoop = nil
        pressedUsages.removeAll()
        lastBatteryQueryAt = nil
        onBatteryStatus?(nil)
    }

    func handleMatchedDevice(_ device: IOHIDDevice) {
        activeDevice = device
        onStatus?("Left Joy-Con portrait input is active; raw L/ZL/L3 supplement attached.")
        requestBatteryStatus(force: true)
    }

    func handleRemovedDevice(_ device: IOHIDDevice) {
        if let activeDevice, CFEqual(activeDevice, device) {
            self.activeDevice = nil
            lastBatteryQueryAt = nil
            onBatteryStatus?(nil)
        }
        pressedUsages.removeAll()
        onStatus?("Left Joy-Con raw L/ZL/L3 supplement disconnected.")
    }

    func requestBatteryStatus(force: Bool = false) {
        guard let activeDevice else { return }
        let now = Date()
        if
            !force,
            let lastBatteryQueryAt,
            now.timeIntervalSince(lastBatteryQueryAt) < 30
        {
            return
        }
        lastBatteryQueryAt = now
        let request = JoyConBatteryHIDProtocol.makeStateRequest(
            packetNumber: packetNumber
        )
        packetNumber = (packetNumber + 1) & 0x0F

        let result = request.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kIOReturnBadArgument
            }
            return IOHIDDeviceSetReport(
                activeDevice,
                kIOHIDReportTypeOutput,
                CFIndex(JoyConBatteryHIDProtocol.outputReportID),
                baseAddress,
                buffer.count
            )
        }
        if result != kIOReturnSuccess {
            lastBatteryQueryAt = nil
            let code = String(format: "0x%08X", UInt32(bitPattern: result))
            onStatus?("Joy-Con battery query failed (\(code)); controller input remains active.")
        }
    }

    func handleInputReport(
        reportID: UInt32,
        report: UnsafeMutablePointer<UInt8>,
        reportLength: CFIndex
    ) {
        guard reportLength > 0 else { return }
        let bytes = Array(
            UnsafeBufferPointer(
                start: report,
                count: Int(reportLength)
            )
        )
        guard let status = JoyConBatteryHIDProtocol.parseBatteryStatus(
            reportID: reportID,
            bytes: bytes
        ) else { return }
        onBatteryStatus?(status)
    }

    func handle(_ value: IOHIDValue) {
        // Refresh only in response to physical activity so battery monitoring
        // does not become a background keep-alive that changes Joy-Con sleep.
        requestBatteryStatus()
        let element = IOHIDValueGetElement(value)
        let usagePage = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let integerValue = IOHIDValueGetIntegerValue(value)

        guard usagePage == LeftJoyConHIDMapping.buttonUsagePage else { return }

        if integerValue == 0 {
            pressedUsages.remove(usage)
        } else {
            guard pressedUsages.insert(usage).inserted else { return }
        }

        guard let input = LeftJoyConHIDMapping.input(forButtonUsage: usage) else {
            if
                integerValue != 0,
                !LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(usage)
            {
                onStatus?("Observed left Joy-Con raw button usage \(usage); GameController owns or has not classified it.")
            }
            return
        }

        onEvent?(
            ControllerEvent(
                input: input,
                phase: integerValue == 0 ? .released : .pressed
            )
        )
    }
}

private func leftJoyConAdapter(
    from context: UnsafeMutableRawPointer?
) -> LeftJoyConHIDAdapter? {
    guard let context else { return nil }
    return Unmanaged<LeftJoyConHIDAdapter>
        .fromOpaque(context)
        .takeUnretainedValue()
}

private func leftJoyConMatchedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess else { return }
    leftJoyConAdapter(from: context)?.handleMatchedDevice(device)
}

private func leftJoyConRemovedCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard result == kIOReturnSuccess else { return }
    leftJoyConAdapter(from: context)?.handleRemovedDevice(device)
}

private func leftJoyConInputCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    value: IOHIDValue
) {
    guard result == kIOReturnSuccess else { return }
    leftJoyConAdapter(from: context)?.handle(value)
}

private func leftJoyConInputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    type: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard result == kIOReturnSuccess else { return }
    leftJoyConAdapter(from: context)?.handleInputReport(
        reportID: reportID,
        report: report,
        reportLength: reportLength
    )
}
