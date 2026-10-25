# Joy-Con Unified Controller

A native macOS menu-bar app that uses one Joy-Con to control **Codex desktop**
and the **Code page in Claude Desktop**. Switch targets with **ZL + Capture**,
select Claude's left/right input, and keep each target's mappings separate.

Community-maintained fork of [Jinjiang/joy-con-codex-micro](https://github.com/Jinjiang/joy-con-codex-micro),
based on the upstream 0.1.12 baseline. Basic single-Joy-Con support comes from
upstream. This repository is an independent development fork.

<p align="center">
  <img src="Assets/AppIcon/AppIcon.png" alt="Joy-Con controller app icon" width="160">
</p>

**Current candidate: 0.2.11.** Locally installed and tested with a left Joy-Con.
The user confirmed Claude recording and input selection, plus ChatGPT chat
navigation, panel shortcuts, scrolling and scroll-to-bottom. Physical reconnect,
automatic desktop restoration and HUD acceptance remain pending. See the
[acceptance record](Docs/Unified-Controller.md#verification-status).

## Features

- One input owner; **ZL + Capture** changes desktop targets while preserving
  ordinary Capture single/double actions. SL/SR are reserved and disabled.
- Separate target profiles, read-only import of the original controller layout,
  and a Test Mode that previews inputs without sending mappings or moving windows.
- Claude Code: **ZL + stick left/right** selects an input in a two-pane layout;
  recording, scrolling and effort controls follow that input.
- Hold/release dictation, repeated scrolling/cursor movement/Backspace, battery
  reporting and raw-HID supplementation for single-left Joy-Con inputs.
- Saved desktop/window layout, manual restore and automatic restore on a live
  controller arrival. A three-second HUD displays **vide coding mode on**.
- Target/focus checks, held-input cleanup and a neutral-input barrier during
  switching; visible errors when permissions or desktop controls are unavailable.

Desktop restoration is experimental and uses private macOS Spaces interfaces.
It verifies the resulting desktop and geometry; a failed second move can leave
one app restored. It does not launch missing apps or restore conversations.

## Supported targets and requirements

| Item | Current support |
| --- | --- |
| Build/runtime | Swift 6; repository toolchain hint: 6.3; macOS 14+ |
| Packaged builds | Apple silicon; other architectures are not validated |
| Desktop restoration | macOS 14.5+; ordinary, non-minimized windows |
| Controller | Nintendo Switch Joy-Con paired in System Settings → Bluetooth; left portrait workflow is the primary tested setup |
| Codex target | `com.openai.codex`; displayed as **Codex** in the controller |
| Claude Code target | `com.anthropic.claudefordesktop`; **Code** page in Claude Desktop |

Local test notes call the `com.openai.codex` target “ChatGPT.” They do not imply
support for the separate ChatGPT app, a browser tab or a terminal-based CLI.
Application updates can change shortcuts and accessibility controls.

## Build

```sh
swift test
bash Scripts/build-release.sh 0.2.11
```

Outputs are under `dist/`:

- `JoyConUnifiedController.app`
- `JoyConUnifiedController-0.2.11-macOS-arm64.zip` on Apple silicon
- Matching `.zip.sha256` file

The build script compiles, packages and ad-hoc signs locally. It does not install
or grant permissions. Builds are not notarized. Use `Package.swift` in Xcode
for development; Swift Package Manager remains the source of truth.

If a toolchain cannot discover Swift Testing, try a matching Xcode toolchain or:

```sh
swift test -Xswiftc -F -Xswiftc "$(xcode-select -p)/Library/Developer/Frameworks"
```

## Install and start

Quit other controller utilities before enabling live output. Install to one
canonical path; this command uses `/Applications` explicitly:

```sh
bash Scripts/install-local-release.sh \
  "dist/JoyConUnifiedController.app" \
  "/Applications/JoyConUnifiedController.app"
```

The installer replaces only the unified identity, backs up the previous bundle,
registers the new path, resets **only its Accessibility grant**, and launches it
with a permission request. System Settings still requires you to enable the app.
Without the second argument the installer defaults to
`~/Applications/JoyConUnifiedController.app`; keep using the same destination
for subsequent upgrades.

1. Pair/connect the Joy-Con and confirm inputs in **Test Mode**.
2. Enable JoyConUnifiedController in **Privacy & Security → Accessibility**.
   Choose **Request / Refresh** in the controller and confirm permission granted.
3. Open the selected desktop target; Claude must be on its Code page.
4. Turn off Test Mode, focus the target, release all held controls, then test a
   harmless action such as scrolling.

Closing the configuration window leaves the menu-bar app running. Use
**Open Controller Window** to reopen it or **Quit Joy-Con Unified Controller** /
`⌘Q` to stop monitoring. [Upgrade and permission recovery](Docs/Accessibility-Upgrades.md).

## Controls

The following is the tested **imported single-left portrait layout** (Minus up),
not a universal factory default. A fresh clone without the legacy profile uses
core starter mappings; saved target profiles and custom actions take precedence.
Inspect the mapping editor before using live output.

| Control | Ordinary | With ZL: Codex / ChatGPT target | With ZL: Claude Code |
| --- | --- | --- | --- |
| D-pad up | Undo `⌘Z` | Close `⌘W` | Same |
| D-pad down | Escape | Bottom panel `⌘J` | Terminal `⌘J` |
| D-pad left | Backspace | Sidebar `⌘⇧S` | Sidebar `⌘B` |
| D-pad right | Enter/confirm | Navigation panel `⌘⇧E` | Changes `⌘⇧D` |
| Minus | New chat `⌘N` | Archive chat `⌘⇧A` | Same imported chord; meaning unverified |
| L hold/release | Start/stop dictation | Same | Same |
| Stick up/down | Scroll up/down | Previous/next sidebar chat `⌘⌥[` / `⌘⌥]` | Previous/next session `⌘⇧[` / `⌘⇧]` |
| Stick left/right | Move caret | Same | Select left/right input; release both afterward |
| Stick click | Scroll to bottom | First chat `⌘1` | First session `⌘1` |
| Capture single/double | Increase/decrease effort | Switch target | Switch target |
| SL/SR | Disabled | Disabled | Disabled |

Hold ZL **before a fresh** stick movement to select Claude's input; release both
before dictation. Switching apps or inputs cancels repeats and releases recording
before accepting fresh input. Claude uses its native **Hold to record** control;
the controller does not record or transcribe audio itself.

The [complete mapping contract](Docs/Unified-Controller.md#mapping-contract)
includes the retained right-controller layout and compatibility rules.

## Saved desktop layout and HUD

Place the two apps on your desired desktops, then choose **记录当前桌面布局**.
If more than one window exists, select one per app and record again. Desktop
numbers 5/6 are an example, not hardcoded destinations. Use **恢复已记录布局**
for a manual check and **预览连接 HUD** to preview the overlay.

Live controller arrivals, including app launch with a connected Joy-Con, restore
the saved layout. Test Mode shows the HUD but pauses window movement. Rescans and
battery updates do not repeat these effects. The HUD is click-through and does
not take focus. Closing a recorded window, deleting a desktop or changing
monitors can require re-recording. [Details and limits](Docs/Unified-Controller.md#desktop-layout-and-connection-hud).

## Profiles and local data

| Data | Location |
| --- | --- |
| Codex profile | `~/Library/Application Support/JoyConUnifiedController/codex-profile.json` |
| Claude profile | `~/Library/Application Support/JoyConUnifiedController/claudeCode-profile.json` |
| Preferences and saved layout | `com.ads1029.JoyConUnifiedController` defaults domain |
| Upgrade backups | `~/Library/Application Support/JoyConUnifiedController/UpgradeBackups/` |
| Installer receipts | `~/Library/Application Support/JoyConUnifiedController/AccessibilityInstallReceipts/` |
| Legacy source, read only | `~/Library/Application Support/JoyConCodexController/mapping-profile.json` |

With no target profile, the legacy layout is imported in memory; launch does not
create profile files. With no usable legacy layout, core starter mappings load.
Known imported Codex shortcuts receive compatibility adjustments; arbitrary custom
actions and saved target profiles are not rewritten. **Restore imported baseline**
affects only the selected target. Invalid files remain intact; recovery uses
in-memory defaults with a warning. Profile writes are atomic.

The controller uses local macOS frameworks, with no Codex/Claude API, telemetry
or controller-side speech service. Scroll diagnostics contain geometry, role
names and event flags, not conversation text. Target apps retain their own
network, recording and microphone behavior.

## Documentation and contribution

- [Changelog](CHANGELOG.md)
- [Contributing and validation](CONTRIBUTING.md)
- [Architecture, controls and acceptance](Docs/Unified-Controller.md)
- [Accessibility upgrades](Docs/Accessibility-Upgrades.md)
- [Maintenance and release checks](Docs/Maintenance.md)
- [Fork identity and upstream policy](Docs/Community-Fork-Maintenance.md)
- [Security reporting](SECURITY.md)
- [Attribution and license status](NOTICE.md)

The tracked upstream snapshot contains no detected `LICENSE`. No independent
license is asserted over inherited code. See [NOTICE.md](NOTICE.md) for the
recorded source and attribution status; this is not a claim that the repository
has an established open-source license.

## Historical interface

These **0.1.12 reference images** predate the unified profiles and shortcut fixes.
Use the current mapping editor/table for bindings.

<details>
<summary>Show historical screenshots</summary>

![Legacy shortcut poster](Assets/README/joy-con-codex-controller-poster.png)
![Legacy configuration window](Assets/README/joy-con-codex-controller-app.png)

</details>
