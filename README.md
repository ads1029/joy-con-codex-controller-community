# Joy-Con Unified Controller

**Control Codex and Claude Code with one Joy-Con on macOS.**

Keep a coding conversation moving with a physical controller: switch agents,
hold a button to dictate, scroll a response, and choose which Claude input to
use. The app runs in the menu bar and routes input to the selected desktop app.

<p align="center">
  <img src="Assets/AppIcon/AppIcon.png" alt="Joy-Con Unified Controller icon" width="128">
</p>

**Development candidate: 0.2.12 · macOS 14+ · Swift 6 · 122 automated tests**

Built on [Jinjiang/joy-con-codex-micro](https://github.com/Jinjiang/joy-con-codex-micro),
with upstream history and attribution retained. This is an independent community
fork. Upstream provides the controller foundation; this fork integrates the
multi-agent desktop workflow described below. Licensed under [MIT](LICENSE),
with upstream attribution and the authorization record in [NOTICE.md](NOTICE.md).

## A controller workflow for coding agents

- **Switch agents with three ZL taps.** Complete three short taps within one
  second to move between Codex and Claude Code. Holding ZL still activates Fn
  immediately. Using another control cancels the tap sequence.
- **Hold L to speak; release to stop.** Codex receives its dictation shortcut.
  Claude uses the selected input's native **Hold to record** control.
- **Choose either Claude input.** Hold ZL and move the stick left or right to
  select that side of a two-pane Code layout. Release both before recording.
  Scrolling and effort changes follow that input too.
- **Keep your existing mappings.** Codex and Claude have separate profiles.
  The earlier controller's configuration is imported read-only when present.
- **Use continuous controls.** Scroll, move the caret, or delete repeatedly
  while holding the corresponding mapped control. Capture single/double taps
  keep their existing effort-increase/decrease actions in the tested profile.

This is a desktop input companion. It does not run a coding agent, proxy a model,
record audio itself, or require an OpenAI/Anthropic API key.

中文速查：**1 秒内完整三击 ZL** 切换应用；**按住 L 录音、松开停止**；
Claude 双栏中用 **ZL＋摇杆左／右** 选择输入框，全部松开后再操作。
Claude Code 中**长按方向键右 2 秒**发送 `⌘Return`。
原 **ZL＋Capture 已停用**，Capture 普通单双击保留。

## What comes from upstream, and what this fork adds

| Area | Inherited foundation | Work maintained in this fork |
| --- | --- | --- |
| Controller input | Native macOS Joy-Con discovery, configurable shortcuts, Fn layers and right-Joy-Con HID support | Left portrait direction correction and raw-HID L/ZL/stick-click supplementation; battery status and diagnostics |
| App control | A local companion for the original Codex shortcut workflow | Separate Codex/Claude profiles, target activation, Claude Code-page checks and target-specific shortcut adaptation |
| Claude two-pane use | — | Explicit left/right prompt selection, native recording-button routing, conversation targeting and effort-menu operations |
| Input lifecycle | Shortcut mapping and held actions | Single/double-tap recognition, continuous repeats, triple-ZL switching, deferred-action cancellation and held-output cleanup across transitions |
| Desktop arrangement | — | Saved app-window/desktop layout, restoration on connection and a nonactivating connection HUD; restoration remains experimental |
| Maintenance | Swift Package Manager app and original interface | Isolated app identity, upgrade backups, permission receipts, regression coverage, contribution/security guidance and documented acceptance limits |

The controller does not ship a second Berrry Joyful process or a copied speech
engine. [CHANGELOG.md](CHANGELOG.md) records the integration and compatibility
work rather than presenting inherited single-Joy-Con support as a new feature.

## Supported setup

| Item | Support and limits |
| --- | --- |
| Codex | Native desktop app, bundle ID `com.openai.codex` |
| Claude Code | **Code page inside Claude Desktop**, bundle ID `com.anthropic.claudefordesktop` |
| Controller | A paired Nintendo Switch Joy-Con; the **single left Joy-Con in portrait orientation, Minus at the top**, is the primary physically tested setup |
| macOS | 14+ for the controller; 14.5+ for experimental desktop restoration |
| Toolchain | Swift 6; repository toolchain hint: 6.3 |
| Build validation | Apple silicon; other architectures and right-controller combinations need separate validation |

Historical local notes sometimes call the Codex target “ChatGPT.” They refer to
`com.openai.codex`, not the separate ChatGPT app, a browser tab or terminal CLI.
Desktop app updates can change shortcuts and accessibility controls.

## Build and try it

The current candidate has been built and exercised locally. It is not presented
as a notarized public binary release. Source is available under [MIT](LICENSE);
signing, notarization and hardware acceptance remain separate release checks.

```sh
swift test
bash Scripts/build-release.sh 0.2.12
```

The build script creates `dist/JoyConUnifiedController.app`, an architecture-named
ZIP and its SHA-256 file. It ad-hoc signs the app; it does not install it or grant
permissions. `Package.swift` is the source of truth and can also be opened in Xcode.

For an authorized local upgrade, quit the current candidate and use one canonical
path consistently:

```sh
bash Scripts/install-local-release.sh \
  "dist/JoyConUnifiedController.app" \
  "/Applications/JoyConUnifiedController.app"
```

The installer verifies the unified identity, backs up the previous candidate,
registers the new path, and refreshes **only that app's Accessibility grant**.
It does not replace the original controller or its configuration. Ad-hoc rebuilds
change the signing identity, so an old enabled permission row is not sufficient.
See [Accessibility upgrades](Docs/Accessibility-Upgrades.md).

1. Pair the Joy-Con in **System Settings → Bluetooth**. Check **Joy-Con ready**.
2. Start in **Test Mode** and inspect the mappings before sending live input.
3. Enable **JoyConUnifiedController** in **Privacy & Security → Accessibility**,
   then choose **Request / Refresh** and confirm permission granted.
4. Open Codex or Claude Desktop's Code page, turn off Test Mode, release all
   controls, and try a harmless action such as scrolling.

Closing the configuration window keeps the controller running in the menu bar.
Use **Open Controller Window** to reopen it, and **Quit** / `⌘Q` to stop it.
Do not run another live controller utility at the same time.

## Controls

**The table below is the tested maintainer profile, imported from the previous
controller.** A fresh installation without that profile uses the core starter
mappings, which differ. Inspect or configure the mapping editor before live use.
Triple-ZL switching and Claude's ZL+horizontal-stick selection are reserved by
the unified session independently of profile edits.

| Left Joy-Con control | Ordinary | Hold ZL: Codex | Hold ZL: Claude Code |
| --- | --- | --- | --- |
| D-pad up | Undo `⌘Z` | Close tab/window `⌘W` | Same |
| D-pad down | Escape | Bottom panel `⌘J` | Terminal `⌘J` |
| D-pad left | Backspace; hold to repeat | Sidebar `⌘⇧S` | Sidebar `⌘B` |
| D-pad right | Enter/confirm; depends on focus | Navigation panel `⌘⇧E` | Changes `⌘⇧D` |
| Minus | New chat `⌘N` | Archive chat `⌘⇧A` | Imported chord; meaning unverified |
| L | Hold to start dictation, release to stop | Same | Same, using the selected input's native control |
| Stick up/down | Scroll up/down; hold to repeat | Previous/next sidebar chat `⌘⌥[` / `⌘⌥]` | Previous/next session `⌘⇧[` / `⌘⇧]` |
| Stick left/right | Move caret; hold to repeat | Same | Select the left/right input, then release both |
| Stick click / L3 | Scroll to conversation bottom | First chat `⌘1` | First session `⌘1` |
| Capture single/double | Increase/decrease reasoning effort | Disabled | Disabled |
| ZL | Hold for immediate Fn; **three complete short taps switch apps** | — | — |
| SL / SR | Disabled | Disabled | Disabled |

**Long press.** Any mapping can add a long-press tap shortcut (default 2 s,
500–5000 ms) in the editor. That control's short action then fires on
release; holding past the threshold sends only the long-press action. In
Claude Code, holding D-pad right for 2 s sends `⌘Return`, provided the profile still has
the imported plain Enter there and no saved Claude profile overrides it.

Triple-ZL limits: each press is at most 300 ms, the release-to-next-press gap is
at most 350 ms, and all three taps finish within one second. Switching happens
on the third release. Other inputs, long holds, suspension or disconnection
clear the sequence. Single/double ZL taps do not switch apps. The former
ZL+Capture switch remains disabled, including when ZL is released first.

App and input changes cancel deferred taps/repeats and release old held output.
Further input waits for cleanup, readiness and neutral controls. If optional
stick-to-focus activates a background target, that first movement is consumed;
release before continuing. Claude input selection requires two visible,
unambiguous side-by-side inputs and reports failure rather than guessing.

## Verification and current limits

| Check | Evidence |
| --- | --- |
| Automated | **122 tests in 19 suites**, including **42 unified transition/profile tests**, passed for 0.2.12 |
| Package | Release build, strict ad-hoc signature, archive CRC, executable mode and binary/checksum checks passed |
| Triple-ZL switch | User physically confirmed Codex → Claude Code → Codex on 0.2.12 |
| Claude input workflow | User confirmed left/right selection, recording in each input, stop on release and right-conversation scrolling on earlier candidates |
| Codex compatibility | User confirmed sidebar navigation, panel shortcuts, scrolling and scroll-to-bottom on earlier candidates |
| Still needs separate native acceptance | Automatic reconnect/launch desktop restoration, HUD behavior, complex multi-pane fallback placement and right-controller coverage |

Earlier native results are not a claim that every action was re-tested on
0.2.12. Capture/Fn preservation has automated regression coverage; no broad
platform or accessibility-device certification is claimed. OpenSpec strict
validation was not run because its CLI was unavailable.

[Architecture and acceptance details](Docs/Unified-Controller.md) ·
[Final validation procedure](Docs/Maintenance.md)

## Optional desktop layout and HUD

Arrange the two apps on your preferred desktops, then choose **记录当前桌面布局**.
Select one window per app if more than one is available. Use **恢复已记录布局**
to test a manual restore and **预览连接 HUD** to preview the overlay.

Layouts store desktop/display identity and window geometry. Desktop numbers 5/6
are an example, not hardcoded destinations. Live connection arrivals can restore
the saved layout; Test Mode pauses window movement. The three-second HUD is
click-through, does not take focus, and displays **vide coding mode on**.

Restoration uses private macOS Spaces interfaces and is experimental. It checks
the resulting desktop and geometry; a failed second move can leave one app
restored. Missing windows, deleted desktops or changed displays can require
re-recording. It does not restore conversations or start missing target apps.

## Local data and privacy

| Data | Location |
| --- | --- |
| Per-target mappings | `~/Library/Application Support/JoyConUnifiedController/{codex,claudeCode}-profile.json` |
| Preferences and saved layout | `com.ads1029.JoyConUnifiedController` defaults domain |
| Previous candidate bundles | `~/Library/Application Support/JoyConUnifiedController/UpgradeBackups/` |
| Installation/permission receipts | `~/Library/Application Support/JoyConUnifiedController/AccessibilityInstallReceipts/` |
| Original profile, imported read-only | `~/Library/Application Support/JoyConCodexController/mapping-profile.json` |

Launch does not create target profile files. Known imported Codex bindings can
receive in-memory compatibility adjustments; saved target profiles and unrelated
custom mappings stay authoritative. Profile writes are atomic. Invalid files
remain intact with a recovery warning.

The controller uses local macOS frameworks and no controller-side model API,
telemetry or speech service. Claude/Codex retain their own network, microphone
and recording behavior. Scroll diagnostics contain geometry, role names and event
flags, not conversation text. Conversation content is not written to controller
logs. See [SECURITY.md](SECURITY.md) for boundaries and reporting.

## Contributing

Reproducible hardware reports, macOS/app compatibility fixes and focused tests
are useful contributions. Include app/controller versions, orientation and the
exact Feedback message. Distinguish an emitted event from a visible app result.

- [Contribution guide](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)
- [Fork identity and upstream policy](Docs/Community-Fork-Maintenance.md)
- [Attribution and license status](NOTICE.md)

## License and attribution

Original project: [Jinjiang/joy-con-codex-micro](https://github.com/Jinjiang/joy-con-codex-micro).
Credit belongs to Jinjiang and the contributors recorded in Git history for the
inherited controller foundation. This fork's additions are maintained separately
and do not imply endorsement by Nintendo, Apple, OpenAI or Anthropic.

This fork is distributed under the [MIT License](LICENSE). On 2026-10-28,
maintainer Minjie Huang confirmed receiving permission from the upstream
maintainer to add MIT to this fork. [NOTICE.md](NOTICE.md) records that basis and
the inherited source attribution. Preserve the copyright and license notices
when redistributing copies or substantial portions of the software.
