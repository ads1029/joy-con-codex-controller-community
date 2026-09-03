import Foundation
import Testing
@testable import JoyConCodexCore

@Suite("Tap sequence recognizer")
struct TapSequenceRecognizerTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test("Single tap remains pending until its deadline")
    func singleTapDeadline() {
        var recognizer = TapSequenceRecognizer()
        #expect(recognizer.press(.buttonCapture, at: start) == .firstTap)
        let release = recognizer.release(
            .buttonCapture,
            at: start.addingTimeInterval(0.05),
            intervalMilliseconds: 280
        )
        guard case let .singlePending(deadline) = release else {
            Issue.record("Expected a pending single tap")
            return
        }
        let early = recognizer.expire(.buttonCapture, at: deadline.addingTimeInterval(-0.001))
        let onTime = recognizer.expire(.buttonCapture, at: deadline)
        let repeated = recognizer.expire(.buttonCapture, at: deadline)
        #expect(!early)
        #expect(onTime)
        #expect(!repeated)
    }

    @Test("Second complete tap inside window resolves as one double tap")
    func doubleTap() {
        var recognizer = TapSequenceRecognizer()
        _ = recognizer.press(.buttonCapture, at: start)
        _ = recognizer.release(
            .buttonCapture,
            at: start.addingTimeInterval(0.04),
            intervalMilliseconds: 280
        )
        #expect(recognizer.press(.buttonCapture, at: start.addingTimeInterval(0.18)) == .secondTap)
        #expect(
            recognizer.release(
                .buttonCapture,
                at: start.addingTimeInterval(0.22),
                intervalMilliseconds: 280
            ) == .doubleTap
        )
        let expired = recognizer.expire(.buttonCapture, at: start.addingTimeInterval(1))
        #expect(!expired)
    }

    @Test("Held button repeat is ignored")
    func repeatEdge() {
        var recognizer = TapSequenceRecognizer()
        #expect(recognizer.press(.buttonCapture, at: start) == .firstTap)
        #expect(recognizer.press(.buttonCapture, at: start.addingTimeInterval(0.01)) == .repeated)
    }

    @Test("An expired first tap lets the next press begin a new sequence")
    func pressAfterExpiry() {
        var recognizer = TapSequenceRecognizer()
        _ = recognizer.press(.buttonCapture, at: start)
        _ = recognizer.release(
            .buttonCapture,
            at: start.addingTimeInterval(0.04),
            intervalMilliseconds: 280
        )
        let expired = recognizer.expire(.buttonCapture, at: start.addingTimeInterval(0.4))
        #expect(expired)
        #expect(recognizer.press(.buttonCapture, at: start.addingTimeInterval(0.41)) == .firstTap)
    }
}
