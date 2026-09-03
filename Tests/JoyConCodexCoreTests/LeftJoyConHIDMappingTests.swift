import Testing
@testable import JoyConCodexCore

@Suite("Left Joy-Con HID supplement")
struct LeftJoyConHIDMappingTests {
    @Test("Raw top button usages become L and ZL")
    func topButtons() {
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 15) == .leftShoulder)
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 16) == .leftTrigger)
    }

    @Test("Raw rail duplicates stay on the GameController path")
    func railDuplicates() {
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 5) == nil)
        #expect(LeftJoyConHIDMapping.input(forButtonUsage: 6) == nil)
        #expect(LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(5))
        #expect(LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(6))
        #expect(!LeftJoyConHIDMapping.isGameControllerOwnedDuplicate(15))
    }

    @Test("Other GameController-owned and unknown usages stay out of the HID supplement")
    func ignoresOtherUsages() {
        for usage in [UInt32(1), 2, 3, 4, 7, 8, 9, 10, 99] {
            #expect(LeftJoyConHIDMapping.input(forButtonUsage: usage) == nil)
        }
    }
}
