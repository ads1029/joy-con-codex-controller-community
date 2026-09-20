import AppKit
import SwiftUI

enum AppSceneID {
    static let mainWindow = "main-controller-window"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            sender.windows.first(where: \.canBecomeMain)?.makeKeyAndOrderFront(nil)
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct JoyConCodexControllerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Joy-Con Codex Controller Community", id: AppSceneID.mainWindow) {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 1_040, minHeight: 760)
        }
        .windowStyle(.titleBar)

        MenuBarExtra {
            MenuBarCompanionView()
                .environmentObject(model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.menuBarStatus.systemImage)
                if let battery = model.activeControllerBattery {
                    Text(battery.compactSummary)
                        .monospacedDigit()
                }
            }
            .accessibilityLabel("Joy-Con Codex Controller Community")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 460)
                .padding()
        }
    }
}
