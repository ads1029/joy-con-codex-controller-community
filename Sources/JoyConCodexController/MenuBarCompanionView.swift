import AppKit
import JoyConCodexCore
import SwiftUI

struct MenuBarCompanionView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    private var status: MenuBarStatus {
        model.menuBarStatus
    }

    var body: some View {
        Group {
            Text("控制目标：\(model.selectedTarget.displayName)")
            ForEach(DesktopTarget.allCases) { target in
                Button(target.displayName) { model.selectTarget(target) }
            }
            Button("ZL + Capture · 切换目标") { model.toggleTarget() }
            Button("聚焦当前目标") { model.focusTarget() }.disabled(model.activationInProgress)
            Divider()
            Label(
                status.controllerSummary,
                systemImage: status.isControllerConnected
                    ? "gamecontroller.fill"
                    : "gamecontroller"
            )
            .disabled(true)

            Label(status.outputSummary, systemImage: outputSystemImage)
                .disabled(true)

            if status.isControllerConnected {
                if let battery = model.activeControllerBattery {
                    Label(battery.summary, systemImage: battery.systemImage)
                        .disabled(true)
                } else {
                    Label("Battery unavailable", systemImage: "battery.0")
                        .disabled(true)
                }
            }

            Divider()

            Toggle("Test Mode", isOn: $model.testMode)
            Toggle("Focus Selected Target on Stick Move", isOn: $model.focusTargetOnStickMove)

            Divider()
            Text(model.desktopLayoutMessage)
            Button("记录当前桌面布局") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: AppSceneID.mainWindow)
                model.captureDesktopLayout()
            }.disabled(model.restoringDesktopLayout)
            Button("恢复已记录布局") { model.restoreDesktopLayout() }
                .disabled(model.testMode || model.restoringDesktopLayout)
            Button("预览连接 HUD") { model.previewCodingHUD() }

            Divider()

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: AppSceneID.mainWindow)
            } label: {
                Label("Open Controller Window", systemImage: "macwindow")
            }

            SettingsLink {
                Label("Settings…", systemImage: "gearshape")
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Joy-Con Unified Controller", systemImage: "power")
            }
            .keyboardShortcut("q")
        }
        .onAppear {
            model.refreshAccessibilityPermission()
        }
    }

    private var outputSystemImage: String {
        switch status.outputState {
        case .testMode:
            "checkmark.shield"
        case .live:
            "keyboard.fill"
        case .blockedByAccessibility:
            "exclamationmark.shield"
        }
    }
}
