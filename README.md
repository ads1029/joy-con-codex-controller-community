# Joy-Con Unified Controller

> Community-maintained fork of [`Jinjiang/joy-con-codex-micro`](https://github.com/Jinjiang/joy-con-codex-micro), based on the upstream 0.1.12 baseline. This is not the upstream project.

<p align="center">
  <img src="Assets/AppIcon/AppIcon.png" alt="Joy-Con Codex Controller Community app icon" width="180">
</p>

A native macOS menu-bar controller for **Codex and the Code page in Claude Desktop**.
Use **ZL + Capture** to switch. Ordinary Capture single/double actions are preserved;
SL/SR are disabled. One process owns controller input and target routing.

The unified app uses bundle identity `com.ads1029.JoyConUnifiedController`, its
own preference domain, and separate per-target JSON files. The old controller
profile is read only as the initial layout; it is never overwritten or migrated
in place. No second Berrry process or Berrry speech engine is run. Berrry Joyful
was reviewed as prior art; the existing controller's mapping core is reused.

## Local candidate (no installation)

```sh
swift test
bash Scripts/build-release.sh 0.2.11
```

Build output: `dist/JoyConUnifiedController.app` and its ZIP/checksum. Building
and signing do not install, register, launch, grant permissions, or alter the old
app. Do not run the installer until explicitly deciding to install this candidate.
When previewing a built candidate, Test Mode is enabled by default. Live output
requires Accessibility for the new identity, and the old controller must be quit
first. The candidate refuses live output while a known other controller runs.

The window and menu bar both display the selected target. Switching releases
held dictation keys, clears repeats/delayed taps, and waits for controls to return
to neutral and the target to be ready. Claude must be on Code; Chat/Cowork do not
receive synthetic input. In split views, select the intended prompt once if the
active pane cannot be determined. In Claude's two-pane layout, **hold ZL, then
move the stick left/right** to focus that side's input. Release ZL and the stick
before holding L to record there. Recording, scrolling and Capture effort actions
follow the selected prompt. The gesture is reserved for Claude; Codex and plain
stick left/right retain their profile mappings. Missing/ambiguous controls block output visibly.

For Claude, known Codex side-panel and side-chat shortcuts become Changes
(`Cmd+Shift+D`) and side chat (`Cmd+;`). Ordinary Capture changes effort through
the active prompt's model menu. Unsupported/custom shortcuts remain visible
keyboard mappings and are not assigned invented meanings. Claude dictation uses the active prompt's native Hold to record control; the
controller does not recognize or type speech itself. Actual speech and
hardware behavior require the manual checks in the acceptance document.

ChatGPT shortcut compatibility (0.2.8): imported ZL+stick up/down use
`Cmd+Option+[` / `]` for previous/next sidebar item/chat. `Cmd+Shift+[` / `]`
switch tabs in the user's current app. Imported Fn sidebar bindings use
`Cmd+Shift+S`, and Fn navigation-panel bindings use `Cmd+Shift+E`;
`Cmd+Option+B` now switches between Chat and tabs. Only exact known bindings
are adapted during legacy import/baseline reset; saved target profiles and
custom actions stay authoritative. Claude retains its existing shortcuts.
See the complete [left/right control table](Docs/Unified-Controller.md#mapping-contract).
The imported ZL+Minus chord `Cmd+Shift+A` archives the current ChatGPT chat;
it is not a stop command.

ChatGPT scrolling locates a focused/unique text input independently of Claude's
prompt labels, then routes wheel events into a real accessible region above
that input in the same column. It requests Electron web accessibility when
needed, supports negative-origin displays, and rejects missing/ambiguous
regions. Failed output remains visible after releasing the stick.
Claude retains its existing split-pane scroll routing.
0.2.10 adds content-free ChatGPT scroll diagnostics to Feedback (event point,
input/region/window rectangles, modifier flags and AX hit-role path) and clears
inherited modifiers on wheel events. A sent event is not proof of page movement.
0.2.11 removes the unnecessary AXValue-assignment requirement for rich-text
input anchors. If ChatGPT cannot expose an input/scroll region, it falls back to
the original controller's point (window center X, 42% down) in its verified
focused window. This target-specific compatibility mode does not use the current
cursor and never activates another app. Diagnostics identify the mode and input
role counts. In complex multi-pane layouts, check where the legacy point lands.

On Claude activation the controller requests Electron's documented
`AXManualAccessibility` support and waits for a web accessibility tree before
looking for Code-page controls. A missing tree produces a readiness error rather
than a misleading missing-selector error. This does not relax Code/Chat routing
or prompt validation. Use **聚焦 Claude Code** to retry after a Claude restart/update.

### Connection HUD and saved desktop layout

Use **记录当前桌面布局** once with Codex and Claude on the desired desktops
(for example desktops 5 and 6). With multiple windows, select the intended window
for each app from the desktop/size/position list, then click record again. Other
windows stay untouched; fullscreen/minimized windows are not restore targets.
The unified app saves selected window identities, desktop UUIDs, display identities and
window frames in its own preferences. **恢复已记录布局** provides a manual check.
Live-mode Joy-Con connections restore that layout, including launch with an
already connected Joy-Con. Test Mode pauses automatic window movement. Rescans
and battery refreshes do not repeat connection effects.

Every supported-controller arrival shows **vide coding mode on** for three
seconds in a click-through, nonactivating HUD on the pointer's display. Its
subtitle distinguishes Test Mode and incomplete restoration. **预览连接 HUD**
previews the overlay without moving windows.

Desktop movement is experimental: it dynamically uses private macOS Spaces
interfaces on macOS 14.5 and later, verifying destination membership and window
geometry. It uses the existing Accessibility permission, with no extra helper
or SIP change. Recording reads WindowServer geometry on inactive desktops;
restoring may briefly activate the apps to obtain their accessible windows,
then returns focus to the previously active app. Deleted desktops, changed displays, fullscreen windows and
ambiguous windows require correction or re-recording; errors are shown.
An error after the first move can leave a partially restored layout. Desktop
UUIDs preserve identity when Mission Control reorders displayed numbers.
The feature does not launch missing apps or restore tabs/conversations.
Closing a recorded window requires re-recording. After an app restarts, matching
is automatic only if it has one candidate window; multiple candidates require
selection again instead of moving an arbitrary window.

Basic single-Joy-Con support is inherited from upstream. This fork maintains
and extends that workflow with battery reporting, raw-HID supplementation,
scrolling, double-tap and repeat behavior, Codex focus behavior, and local
installation/accessibility guidance.

## Upstream source

This project is based on the original [`Jinjiang/joy-con-codex-micro`](https://github.com/Jinjiang/joy-con-codex-micro) repository.

- **Upstream repository:** <https://github.com/Jinjiang/joy-con-codex-micro>
- **Fork baseline:** upstream `0.1.12`
- **Relationship:** this is an independent community-maintained fork, not an
  official upstream release
- **Inherited behavior:** basic single-Joy-Con support, mapping, and the
  original controller workflow come from upstream
- **Fork-specific work:** battery reporting, raw-HID supplementation,
  scrolling, double-tap/repeat behavior, Codex focus behavior, and packaging
  and Accessibility guidance

Changes in this fork should preserve the original attribution and clearly
separate inherited behavior from fork-specific changes.

## License and attribution

The upstream repository currently has no detected `LICENSE` file. This fork
retains the upstream URL, author attribution, and history. No independent
license is asserted for inherited source; public redistribution of modified
source or builds remains subject to explicit upstream permission or a clear
license.

The companion is local and framework-only: no Codex API or network service is required.

> **Development candidate 0.2.11** — installed locally for the approved
> Codex / Claude Desktop Code integration. The original 0.1.12 controller and
> configuration are preserved. The user confirmed Claude recording and ChatGPT
> chat navigation, panel shortcuts and scrolling; physical reconnect/HUD acceptance
> remains pending. This candidate has not been promoted stable.
> See [the design and acceptance contract](Docs/Unified-Controller.md).

<p align="center">
  <img src="Assets/README/joy-con-codex-controller-poster.png" alt="Joy-Con Codex Controller Community default and function-layer shortcut mappings" width="820">
</p>

## Legacy interface reference (0.1.12)

<p align="center">
  <img src="Assets/README/joy-con-codex-controller-app.png" alt="Joy-Con Codex Controller Community macOS configuration window" width="920">
</p>

## Requirements

- macOS 14 or newer
- Swift 6 (Swift 6.3 is used by the bootstrap environment)
- A full Xcode installation for signing, entitlements, Archive builds, and hardware/UI validation
- A Nintendo Switch Joy-Con paired in **System Settings → Bluetooth**

The project uses Swift Package Manager as its source of truth. Open `Package.swift` in Xcode for app development, or use the command line:

```sh
swift build
swift test -Xswiftc -F -Xswiftc "$(xcode-select -p)/Library/Developer/Frameworks"
swift run JoyConUnifiedController
```

The explicit framework search path is needed by the current standalone Command Line Tools image so SwiftPM’s generated runner can discover the bundled Swift Testing framework. A full matching Xcode toolchain normally supports plain `swift test`.

## Background operation and menu bar

Joy-Con Unified Controller runs as a menu-bar accessory, so it does not occupy a permanent Dock position. The red window close button closes the configuration window but intentionally leaves the companion process running so Joy-Con mappings can continue while another app is frontmost. While the process is active, the menu bar displays a controller icon with:

- Joy-Con connection status
- Battery percentage and charge state when macOS exposes `GCController.battery`
- Test mode, live output, or Accessibility-blocked status
- A Test Mode toggle that immediately controls shortcut suppression
- **Open Controller Window** to restore the main window after it is closed
- **Settings…** and **Quit Joy-Con Codex Controller Community** actions

Use the menu’s Quit action or `Command-Q` to terminate the process and stop controller monitoring completely.

## Permissions

The app uses Apple’s public GameController framework. Bluetooth pairing remains owned by macOS; the app discovers controllers that macOS already exposes.

Posting keyboard shortcuts requires **Accessibility** permission:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Enable the built app or the development host running it.
3. If macOS requests **Input Monitoring** for a particular signed build or OS version, grant it under **Privacy & Security → Input Monitoring**.

Ad-hoc local builds receive a new code-directory hash on every rebuild, so an
enabled Accessibility row from an older build can target the wrong binary
identity. Do not replace and launch local release bundles manually. Use
`Scripts/install-local-release.sh` for every local upgrade; it installs the new
bundle first, resets TCC in the correct order, registers the canonical path, and
launches the new process with an explicit permission request. See
[`Docs/Accessibility-Upgrades.md`](Docs/Accessibility-Upgrades.md) for the full
procedure, verification receipt, recovery steps, and stable-signing guidance.

Test mode is enabled on first launch. In test mode, controller inputs, the selected Default/Fn layer, resolved mappings, and known ChatGPT function descriptions are displayed, but no synthetic keyboard event is posted. Enabling test mode also releases any live hold-to-dictate key before output is suppressed.

`GCController.shouldMonitorBackgroundEvents` is enabled so controller input can reach the app while Codex is frontmost, subject to macOS policy and the build’s signing context.

The Controller card and menu-bar title read battery information from Apple's
public `GCController.battery` API and refresh it every 30 seconds. A controller
that does not expose battery data through macOS is shown as **Battery
unavailable** rather than receiving an estimated value.

For a single left Joy-Con, macOS may create a battery object whose level remains
at `0.0`. The raw HID supplement therefore sends the no-op **Get Controller
State** subcommand and reads the Joy-Con's five-step battery field from the
`0x21` reply. Raw levels are labeled as approximate (for example,
**High (≈75%) · On battery · Joy-Con HID**) instead of being presented as an
exact percentage. The query preserves the current input-report mode and does
not change mappings or controller firmware. Raw queries run on connection,
manual rescan, and throttled physical activity; the 30-second UI refresh does
not transmit background keep-alives, so battery display does not change the
controller's idle-sleep behavior.

## Single left Joy-Con orientation

The controller card and Settings window include a **Left Joy-Con grip** selector.
**Portrait — Minus at top** is the default. It reads the controller's dynamic
physical input profile, translates Apple's horizontal A/B/X/Y labels back to
the printed left D-pad directions, maps Menu/Home to Minus/Capture, maps the two
reported micro-gamepad shoulders to SL/SR, and rotates the reported stick axes into portrait
coordinates. **Sideways — rail at top** restores the earlier micro-gamepad path.

For a single left Joy-Con, macOS reports the rail SL/SR buttons as the generic
micro-gamepad shoulders. The app translates those two GameController fields to
SL/SR. It also opens Nintendo vendor `0x057E`, product `0x2006` through IOKit
and merges only raw L/ZL usages 15/16. Raw SL/SR usages 5/6 are ignored so one
physical rail press produces exactly one logical event.

For hardware discovery, the included logger defaults to the left Joy-Con:

```sh
swift run JoyConInputLogger          # left 0x2006
swift run JoyConInputLogger --right  # right 0x2007
```

## Core starter defaults (reference)

The `Codex Keyboard Layers` starter profile is designed for one Joy-Con held in portrait orientation. The Plus/Minus end is up and the Home/Capture end is down. A right Joy-Con uses A/B/X/Y; the left Joy-Con direction in the same physical position has the same action.

ZL and ZR are internal Fn controls. They post no keyboard event, and the Fn layer remains active until both are released. The target action is selected when the target input is pressed, so pressing Fn after an action does not change or repeat it.

| Joy-Con input | Default | While ZL or ZR is held |
| --- | --- | --- |
| SL | Disabled in unified controller | Disabled |
| SR | Disabled in unified controller | Disabled |
| A / left D-pad right | `Return` — Enter / confirm | `⌘⌥B` — Toggle side panel |
| B / left D-pad down | `Escape` — Cancel or dismiss | `⌘J` — Toggle bottom panel |
| X / left D-pad up | `⌘⌥S` — New side chat | `⌘W` — Close chat |
| Y / left D-pad left | `Delete` — Delete previous character | `⌘B` — Toggle sidebar |
| Plus / Minus | `⌘N` — New chat | Disabled |
| L or R | Hold `⌃⇧D` — Voice dictation | Same as Default |
| ZL or ZR | Function layer | Function layer |
| Stick up/down | Matching arrow-key tap | Same as Default |
| Stick left/right | Matching arrow-key tap | Claude + ZL: select left/right input; otherwise profile mapping |
| Home | Disabled | Disabled |
| Capture | Imported single/double action | ZL + Capture switches targets |
| Stick press | Disabled | Disabled |

These are core starter values for reference. The unified controller initially reads the existing saved layout, including its custom stick scrolling and Capture actions. **Restore imported baseline** restores a read-only copy of the old layout into the selected unified profile; it never resets the old controller.

L and R share one held dictation chord: the first voice control posts key-down, and the final released voice control posts key-up. Controller disconnect, profile changes, test mode, and ordinary application termination also release any active hold.

Stick directions use edge detection. Scroll, left/right cursor and Backspace mappings repeat according to the shared repeat policy; other shortcuts do not auto-repeat. Activation uses a higher threshold than release so small threshold jitter does not retrigger arrow keys. Severe hardware drift can still produce input; leave the app in test mode while checking a worn controller.

The mapping editor shows Default and Fn slots separately. Disabled slots say **Disabled**, tap and hold behavior is identified, and exact known ChatGPT chords include a plain-language description. Custom chords remain editable but receive no invented ChatGPT meaning.

The editor also includes an interactive portrait Joy-Con diagram. Selecting a mapping or clicking a control on the diagram highlights its physical location in yellow. Pressing a connected Joy-Con control selects that mapping and shows a green live-input highlight, including individual stick directions and the duplicated SL/SR rail positions.

Output is restricted to the selected desktop application. With **Focus selected target on stick movement** enabled, the first stick direction focuses that target and is consumed. Release the controls before continuing. Scrolling uses the accessible active conversation area rather than the pointer location. The controller uses no Codex/Claude API or network service.

On first launch, test mode is enabled and prevents every mapping from posting keyboard events. To use live output, turn off test mode and grant Accessibility permission. Because background controller monitoring remains active while the process is running, live mappings can continue after the main window is closed; use `⌘Q` or the app’s Quit command to stop the process completely.

## Profiles

Mappings are stored as versioned JSON at:

```text
~/Library/Application Support/JoyConUnifiedController/codex-profile.json
~/Library/Application Support/JoyConUnifiedController/claudeCode-profile.json
```

Writes are atomic. If the stored file is unreadable or invalid, it is left untouched and the app loads starter defaults in memory. The same validated JSON format is used for import and export.

Schema-v1 profiles are migrated in memory to schema 2. Existing enabled shortcuts remain Default tap actions, existing disabled mappings stay disabled, and their Fn slots remain disabled. Inputs that are entirely absent from an older profile are added with their current starter values so newly supported controls appear, but existing entries are never overwritten. **Restore imported baseline** affects only the selected unified target. SL/SR and ZL + Capture remain reserved.

## Signing and distribution

SwiftPM command-line builds verify the source and tests, but they do not replace an Xcode app archive. Before distribution:

- Select a development team and signing identity in Xcode.
- Review App Sandbox and input-event entitlements for the intended distribution channel.
- Test background GameController delivery and Accessibility prompts using the final signed bundle.
- Archive, notarize, and staple the app as appropriate.

## Hardware verification limits

Automated tests cover profile defaults, schema migration, layered resolution, hold ownership and cleanup, side-aware direction normalization, stick hysteresis, persistence, and test-mode suppression. This environment does not have a Joy-Con attached, so these remain manual checks:

- Separate left/right Joy-Con identity strings and element availability
- Whether the target macOS release exposes every left Joy-Con D-pad, SL/SR, L/ZL, stick, Minus, and Capture input
- Portrait axis orientation and drift thresholds on worn left and right Joy-Cons
- Hold-to-dictate behavior against the installed ChatGPT shortcut configuration
- Background input delivery for the final signed app
- Accessibility and Input Monitoring prompts for the final bundle
- Joy-Con haptic locality availability and playback
- SwiftUI layout and import/export panels in a full Xcode-launched app

Basic controller haptics are best-effort. Visual feedback always remains available, and a haptic setup or playback failure never blocks shortcut processing.

## OpenSpec

Active changes are tracked under `openspec/changes`, while completed changes are retained under `openspec/changes/archive`. Validate the complete specification tree with:

```sh
openspec validate --all --strict
```

## Maintenance status

The project entered maintenance on 2026-09-13. Version 0.1.12 remains the
supported baseline. The existing controller mapping, profile, menu-bar,
Accessibility, battery, portrait-orientation, and raw-HID supplement features
are considered feature-complete for the current scope.

Maintenance releases must preserve the current safe defaults, include a focused
regression test, keep documentation synchronized, and pass the release checks in
[`Docs/Maintenance.md`](Docs/Maintenance.md). Library or framework upgrades alone
do not reopen feature development.

The community-fork workflow, attribution rules, identity changes, upstream
sync policy, and release sequence are tracked in
[`Docs/Community-Fork-Maintenance.md`](Docs/Community-Fork-Maintenance.md).

### 0.1.12: left stick click input fix

Single-left micro-gamepad input now supplements raw HID button usage 11 as
`leftStickPress`. Existing primary and function-layer profile actions are preserved.
The extended-gamepad path already owns stick clicks and does not attach this
supplement. Regression tests start at the raw usage mapping and verify primary
scroll, ZL + click, release/repress, and Test Mode suppression. Physical controller
delivery and actual Codex scrolling remain on-device maintenance checks.
