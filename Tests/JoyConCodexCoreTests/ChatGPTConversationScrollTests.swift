import CoreGraphics
import Testing
@testable import JoyConCodexCore

@Suite("ChatGPT conversation scroll routing")
struct ChatGPTConversationScrollTests {
    private let window = CGRect(x: 0, y: 0, width: 1400, height: 1000)

    @Test("Legacy routing preserves the original point on a portrait display")
    func legacyWindowCompatibility() {
        let portrait = CGRect(x: -1440, y: -462, width: 1440, height: 2535)
        let point = ChatGPTConversationScroll.legacyWindowPoint(window: portrait)
        #expect(point?.x == -720)
        #expect(point?.y == portrait.minY + portrait.height * 0.42)
        #expect(point.map(portrait.contains) == true)
        #expect(ChatGPTConversationScroll.legacyWindowPoint(window: .zero) == nil)
    }

    @Test("Rich-text inputs can anchor scrolling without AXValue assignment support or Claude labels")
    func richTextAnchor() {
        let input = CGRect(x: 300, y: 880, width: 550, height: 60)
        #expect(ChatGPTConversationScroll.isInputAnchor(role: "AXTextArea", frame: input, window: window))
        #expect(ChatGPTConversationScroll.isInputAnchor(role: "AXTextField", frame: input, window: window))
        #expect(!ChatGPTConversationScroll.isInputAnchor(role: "AXStaticText", frame: input, window: window))
        #expect(!ChatGPTConversationScroll.isInputAnchor(role: "AXTextArea", frame: input.offsetBy(dx: 2000, dy: 0), window: window))
    }

    @Test("The input column excludes the sidebar and adjacent browser")
    func excludesOtherPanes() {
        let composer = CGRect(x: 300, y: 880, width: 550, height: 60)
        let transcript = CGRect(x: 270, y: 80, width: 620, height: 780)
        let sidebar = CGRect(x: 0, y: 40, width: 240, height: 920)
        let browser = CGRect(x: 930, y: 40, width: 470, height: 920)
        let point = ChatGPTConversationScroll.point(window: window, composer: composer, regions: [browser, sidebar, transcript])
        #expect(point != nil)
        #expect(point.map(transcript.contains) == true)
        #expect(point.map(sidebar.contains) == false)
        #expect(point.map(browser.contains) == false)
    }

    @Test("Two chat panes follow the selected editable input")
    func splitChat() {
        let left = CGRect(x: 260, y: 80, width: 500, height: 780)
        let right = CGRect(x: 800, y: 80, width: 540, height: 780)
        let composer = CGRect(x: 820, y: 880, width: 500, height: 60)
        let point = ChatGPTConversationScroll.point(window: window, composer: composer, regions: [left, right])
        #expect(point.map(right.contains) == true)
        #expect(point.map(left.contains) == false)
    }

    @Test("Nested web regions use the input column on a negative-origin portrait display")
    func nestedPortraitRegions() {
        let window = CGRect(x: -1440, y: -462, width: 1440, height: 2535)
        let composer = CGRect(x: -1150, y: 1950, width: 1000, height: 80)
        let transcript = CGRect(x: -1180, y: -370, width: 1080, height: 2300)
        let point = ChatGPTConversationScroll.point(window: window, composer: composer, regions: [window, transcript])
        #expect(point.map(transcript.contains) == true)
        #expect(point?.x == composer.midX)
        #expect(ChatGPTConversationScroll.route(window: window, composer: composer, regions: [window, transcript])?.regionIndex == 1)
    }

    @Test("Missing, offscreen and unrelated regions never fall back to a window center")
    func refuseInvalidRegions() {
        let composer = CGRect(x: 300, y: 880, width: 550, height: 60)
        #expect(ChatGPTConversationScroll.point(window: window, composer: composer, regions: []) == nil)
        #expect(ChatGPTConversationScroll.point(window: window, composer: composer, regions: [CGRect(x: 1500, y: 0, width: 500, height: 900)]) == nil)
        #expect(ChatGPTConversationScroll.point(window: window, composer: .zero, regions: [window]) == nil)
        #expect(ChatGPTConversationScroll.point(window: window, composer: composer, regions: [CGRect(x: 0, y: 0, width: 200, height: 900)]) == nil)
        let unrelated = [CGRect(x: 250, y: 100, width: 700, height: 780),
                         CGRect(x: 300, y: 80, width: 600, height: 800)]
        #expect(ChatGPTConversationScroll.point(window: window, composer: composer, regions: unrelated) == nil)
    }
}
