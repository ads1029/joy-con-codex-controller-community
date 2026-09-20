# Joy-Con Codex Controller Community

> Community-maintained fork of [`Jinjiang/joy-con-codex-micro`](https://github.com/Jinjiang/joy-con-codex-micro), based on the upstream 0.1.12 baseline. This is not the upstream project.

<p align="center">
  <img src="Assets/AppIcon/AppIcon.png" alt="Joy-Con Codex Controller Community app icon" width="180">
</p>

A native macOS companion that turns an already paired Nintendo Switch Joy-Con into a configurable keyboard-shortcut controller.

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

> **Project status: Community maintenance** — Version 0.1.12 is the stable
> upstream/fork baseline. The next fork release will be versioned separately.
> New feature development is paused. Future work is limited to reproducible bug
> fixes, macOS compatibility, security, packaging, and adjustments supported by
> real controller usage. See [`Docs/Maintenance.md`](Docs/Maintenance.md).

<p align="center">
  <img src="Assets/README/joy-con-codex-controller-poster.png" alt="Joy-Con Codex Controller Community default and function-layer shortcut mappings" width="820">
</p>

## App interface

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
swift run JoyConCodexControllerCommunity
```

The explicit framework search path is needed by the current standalone Command Line Tools image so SwiftPM’s generated runner can discover the bundled Swift Testing framework. A full matching Xcode toolchain normally supports plain `swift test`.

## Background operation and menu bar

Joy-Con Codex Controller Community runs as a menu-bar accessory, so it does not occupy a permanent Dock position. The red window close button closes the configuration window but intentionally leaves the companion process running so Joy-Con mappings can continue while another app is frontmost. While the process is active, the menu bar displays a controller icon with:

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

## Default layered keyboard mappings

The `Codex Keyboard Layers` starter profile is designed for one Joy-Con held in portrait orientation. The Plus/Minus end is up and the Home/Capture end is down. A right Joy-Con uses A/B/X/Y; the left Joy-Con direction in the same physical position has the same action.

ZL and ZR are internal Fn controls. They post no keyboard event, and the Fn layer remains active until both are released. The target action is selected when the target input is pressed, so pressing Fn after an action does not change or repeat it.

| Joy-Con input | Default | While ZL or ZR is held |
| --- | --- | --- |
| SL | `⌘⇧[` — Previous chat | `⌘[` — Back |
| SR | `⌘⇧]` — Next chat | `⌘]` — Forward |
| A / left D-pad right | `Return` — Enter / confirm | `⌘⌥B` — Toggle side panel |
| B / left D-pad down | `Escape` — Cancel or dismiss | `⌘J` — Toggle bottom panel |
| X / left D-pad up | `⌘⌥S` — New side chat | `⌘W` — Close chat |
| Y / left D-pad left | `Delete` — Delete previous character | `⌘B` — Toggle sidebar |
| Plus / Minus | `⌘N` — New chat | Disabled |
| L or R | Hold `⌃⇧D` — Voice dictation | Same as Default |
| ZL or ZR | Function layer | Function layer |
| Stick up/down/left/right | Matching arrow-key tap | Same as Default |
| Home, Capture | Disabled | Disabled |
| Stick press | Disabled | Disabled |

These values are the 0.1.1 starter defaults, not a forced update to an existing profile. Updating or relaunching the app leaves saved mappings in place. To adopt this exact table, choose **Restore Defaults**, which replaces and saves every current mapping; otherwise edit only the desired slots.

L and R share one held dictation chord: the first voice control posts key-down, and the final released voice control posts key-up. Controller disconnect, profile changes, test mode, and ordinary application termination also release any active hold.

Stick directions are edge-triggered and do not auto-repeat while held. Activation uses a higher threshold than release so small threshold jitter does not retrigger arrow keys. Severe hardware drift can still produce input; leave the app in test mode while checking a worn controller.

The mapping editor shows Default and Fn slots separately. Disabled slots say **Disabled**, tap and hold behavior is identified, and exact known ChatGPT chords include a plain-language description. Custom chords remain editable but receive no invented ChatGPT meaning.

The editor also includes an interactive portrait Joy-Con diagram. Selecting a mapping or clicking a control on the diagram highlights its physical location in yellow. Pressing a connected Joy-Con control selects that mapping and shows a green live-input highlight, including individual stick directions and the duplicated SL/SR rail positions.

These are ordinary keyboard events delivered to whichever application is frontmost. For example, `⌘⌥S`, `⌘W`, or `⌘N` can mean something different in another application. With **Focus Codex on stick movement** enabled, the first stick direction activates Codex and is consumed; subsequent directions use their mappings. The companion does not use a Codex API.

On first launch, test mode is enabled and prevents every mapping from posting keyboard events. To use live output, turn off test mode and grant Accessibility permission. Because background controller monitoring remains active while the process is running, live mappings can continue after the main window is closed; use `⌘Q` or the app’s Quit command to stop the process completely.

## Profiles

Mappings are stored as versioned JSON at:

```text
~/Library/Application Support/JoyConCodexController/mapping-profile.json
```

Writes are atomic. If the stored file is unreadable or invalid, it is left untouched and the app loads starter defaults in memory. The same validated JSON format is used for import and export.

Schema-v1 profiles are migrated in memory to schema 2. Existing enabled shortcuts remain Default tap actions, existing disabled mappings stay disabled, and their Fn slots remain disabled. Inputs that are entirely absent from an older profile are added with their current starter values so newly supported controls appear, but existing entries are never overwritten. Choose **Restore Defaults** only when you want to replace the complete saved profile with the current starter layout.

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
