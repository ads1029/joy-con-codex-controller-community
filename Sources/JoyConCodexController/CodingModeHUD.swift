import AppKit
import SwiftUI

@MainActor
final class CodingModeHUD {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(detail: String) {
        dismissal?.cancel()
        panel?.orderOut(nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 430, height: 112),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView:
            HStack(spacing: 16) {
                Image(systemName: "gamecontroller.fill").font(.system(size: 32)).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 6) {
                    Text("vide coding mode on").font(.system(size: 23, weight: .semibold))
                    Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(22).frame(width: 430, height: 112)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        )
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - 215, y: frame.minY + 100))
        }
        self.panel = panel
        panel.orderFrontRegardless()
        dismissal = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }
}
