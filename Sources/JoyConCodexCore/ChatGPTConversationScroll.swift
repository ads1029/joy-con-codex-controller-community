import CoreGraphics

/// Semantic conversation routing plus explicit original-controller compatibility.
/// Neither path depends on where the user's mouse currently happens to be.
public enum ChatGPTConversationScroll {
    /// Original-controller compatibility after verifying the focused ChatGPT window.
    public static func legacyWindowPoint(window: CGRect) -> CGPoint? {
        guard valid(window), window.width > 300, window.height > 300 else { return nil }
        return CGPoint(x: window.midX, y: window.minY + window.height * 0.42)
    }

    public static func isInputAnchor(role: String, frame: CGRect, window: CGRect) -> Bool {
        // A rich-text composer may expose text input without AXValue assignment.
        // Scrolling reads geometry; it does not need permission to write a value.
        (role == "AXTextArea" || role == "AXTextField") && valid(frame)
            && frame.width >= 80 && frame.height >= 12
            && window.contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    public struct Route {
        public let point: CGPoint
        public let regionIndex: Int
    }

    public static func point(window: CGRect, composer: CGRect, regions: [CGRect]) -> CGPoint? {
        route(window: window, composer: composer, regions: regions)?.point
    }

    public static func route(window: CGRect, composer: CGRect, regions: [CGRect]) -> Route? {
        guard valid(window), valid(composer), composer.width >= 80, composer.height >= 12,
              window.contains(CGPoint(x: composer.midX, y: composer.midY)) else { return nil }
        let candidates = regions.enumerated().compactMap { index, region -> (index: Int, rect: CGRect)? in
            guard valid(region) else { return nil }
            let clipped = region.intersection(window)
            guard clipped.width >= 160, clipped.height >= 100,
                  composer.midX > clipped.minX + 12, composer.midX < clipped.maxX - 12,
                  clipped.minY < composer.minY - 40,
                  clipped.maxY >= composer.minY - 120 else { return nil }
            return (index, clipped)
        }
        // Nested native/web scroll containers describe the same column. Two
        // unrelated regions remain ambiguous instead of picking traversal order.
        let aboveInput = candidates.filter { !$0.rect.contains(CGPoint(x: composer.midX, y: composer.midY)) }
        let regions = aboveInput.isEmpty ? candidates : aboveInput
        guard let outer = regions.max(by: { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }),
              regions.allSatisfy({ outer.rect.insetBy(dx: -2, dy: -2).contains($0.rect) }) else { return nil }
        let point = CGPoint(x: composer.midX, y: min(composer.minY - 64, outer.rect.maxY - 16))
        guard point.y >= outer.rect.minY + 16, window.contains(point) else { return nil }
        return Route(point: point, regionIndex: outer.index)
    }

    private static func valid(_ rect: CGRect) -> Bool {
        !rect.isNull && !rect.isInfinite && !rect.isEmpty
            && rect.minX.isFinite && rect.minY.isFinite && rect.width.isFinite && rect.height.isFinite
    }
}
