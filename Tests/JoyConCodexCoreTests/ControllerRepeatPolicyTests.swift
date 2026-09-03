import Testing
@testable import JoyConCodexCore

@Suite("Continuous controller output")
struct ControllerRepeatPolicyTests {
    @Test("Stick left and right repeat their arrow taps")
    func horizontalStickRepeat() {
        let left = MappingAction.tap(
            Shortcut(keyCode: 123, displayLabel: "Left Arrow")
        )
        let right = MappingAction.tap(
            Shortcut(keyCode: 124, displayLabel: "Right Arrow")
        )

        #expect(ControllerRepeatPolicy.plan(for: .leftStickLeft, action: left)?.output == .keyboardTap(left.shortcut!))
        #expect(ControllerRepeatPolicy.plan(for: .leftStickRight, action: right)?.output == .keyboardTap(right.shortcut!))
    }

    @Test("D-pad left repeats Delete but not its Fn sidebar command")
    func deleteRepeatOnly() {
        let delete = MappingAction.tap(
            Shortcut(keyCode: 51, displayLabel: "Delete")
        )
        let sidebar = MappingAction.tap(
            Shortcut(keyCode: 11, displayLabel: "B", modifiers: [.command])
        )

        #expect(ControllerRepeatPolicy.plan(for: .dpadLeft, action: delete) != nil)
        #expect(ControllerRepeatPolicy.plan(for: .dpadLeft, action: sidebar) == nil)
    }

    @Test("Scroll directions repeat and scroll-to-bottom remains one shot")
    func scrollPolicy() {
        #expect(ControllerRepeatPolicy.plan(for: .leftStickUp, action: .scrollUp)?.output == .scroll(.up))
        #expect(ControllerRepeatPolicy.plan(for: .leftStickDown, action: .scrollDown)?.output == .scroll(.down))
        #expect(ControllerRepeatPolicy.plan(for: .leftStickPress, action: .scrollToBottom) == nil)
    }
}
