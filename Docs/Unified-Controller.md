# Unified desktop controller: behavior and acceptance

Current release: **0.3.0**. This document describes the implemented
contract and separates automated checks from physical acceptance. Historical
candidate changes are in [CHANGELOG.md](../CHANGELOG.md).

## Architecture and ownership

One GameController/HID adapter owns device input. The existing mapping engine,
hold ownership, repeat policy and tap recognizer remain shared. The session
recognizes three complete ZL taps independently of Capture double-tap recognition. Each desktop target has its
own profile, application identity, readiness checks and scroll destination.

| Layer | Responsibility |
| --- | --- |
| `JoyConCodexCore` | Mapping/profile models, target adapters, session transitions, connection-edge tracking, geometry/window matching and testable policy |
| `AppModel` | UI state, target activation, profile operations, connection effects and visible failures |
| `DesktopApplicationDriver` | Foreground target, Claude Code/prompt readiness, native controls and scroll coordinates |
| `CoreGraphicsShortcutEmitter` | Destination revalidation, key/scroll/native-record events and held-output recovery |
| `DesktopLayoutController` | Selected-window capture and verified Spaces/geometry restoration |
| `CodingModeHUD` | Nonactivating, click-through connection overlay |

Switching cancels delayed taps/repeats and releases holds at the old destination.
Input is suppressed until cleanup, readiness and neutral controls complete.
Failed cleanup blocks new output. Test Mode changes the preview target without
activating apps, emitting mappings or restoring windows; entering it releases
previous live holds. A manually focused selected target can accept fresh input
without requiring an extra stick activation. Optional stick-to-focus consumes
the first movement; release before continuing.

New output validates permission, selected foreground identity and known competing
controller processes. A failure never falls through to another app. Codex's
keyboard readiness does not depend on Claude's prompt-label matcher.

## Targets and isolation

| Target | Bundle identifier | Profile |
| --- | --- | --- |
| `codex` / Codex | `com.openai.codex` | `codex-profile.json` |
| `claudeCode` / Claude Code | `com.anthropic.claudefordesktop` | `claudeCode-profile.json` |

Local ChatGPT test references mean the `codex` desktop target, not a separate
ChatGPT app/browser/CLI adapter. Claude means the Code page in Claude Desktop.
Its outer page URL takes precedence over radio state: Code/epitaxy URLs can be
accepted without an exposed selected value; a Chat URL cannot pass on stale
Code selection. Cached page references are revalidated.

The app/product is `JoyConUnifiedController`; its bundle/defaults identity is
`com.ads1029.JoyConUnifiedController`. Profiles live under
`~/Library/Application Support/JoyConUnifiedController/`. Bundled runs use their
own standard defaults; CLI runs use a named suite. An unavailable suite stays
in memory rather than falling back to another host's defaults.

When a target file is absent, the original
`JoyConCodexController/mapping-profile.json` is read only into memory, or starter
mappings are used. Launch does not create target files. Saves are atomic and
target-local. Invalid source files remain intact with a recovery warning.
The original app, preferences and legacy profile are preserved. SL/SR and the
triple-ZL switch remain reserved independently of profile edits; the old ZL+Capture chord is disabled.

## Mapping contract

Current single-left portrait baseline (Minus up). ChatGPT is the app still
identified internally as target `codex`. Values reflect the user's imported
layout plus target adapters, not generic core defaults.

| Physical control | Ordinary | Hold ZL: ChatGPT | Hold ZL: Claude Code |
| --- | --- | --- | --- |
| D-pad up | Undo `Cmd+Z` | Close tab/window `Cmd+W` | Same |
| D-pad down | Escape | Bottom panel `Cmd+J` | Terminal `Cmd+J` |
| D-pad left | Backspace | Sidebar `Cmd+Shift+S` | Sidebar `Cmd+B` |
| D-pad right | Enter/confirm (focus dependent) | Navigation panel `Cmd+Shift+E` | Changes `Cmd+Shift+D` |
| Minus | New chat `Cmd+N` | Archive chat `Cmd+Shift+A` | Same imported chord; meaning not verified |
| L hold/release | Start/stop dictation (ChatGPT shortcut, Claude native control) | Same | Same |
| Stick up | Scroll up | Previous sidebar item/chat `Cmd+Option+[` | Previous session `Cmd+Shift+[` |
| Stick down | Scroll down | Next sidebar item/chat `Cmd+Option+]` | Next session `Cmd+Shift+]` |
| Stick left/right | Cursor left/right | Same | Select left/right input; release both afterward |
| Stick click | Scroll to bottom | Chat 1 `Cmd+1` | Session 1 `Cmd+1` |
| Capture single | Increase effort (ChatGPT `Ctrl+Option+Right`, Claude model menu) | Disabled | Disabled |
| Capture double | Decrease effort (ChatGPT `Ctrl+Option+Left`, Claude model menu) | Disabled | Disabled |
| ZL | Hold for immediate Fn; three quick complete taps switch apps | — | — |
| SL/SR | Disabled | Disabled | Disabled |

Right-controller retained mappings: A/B/X/Y ordinary Enter/Escape/side chat/
Backspace; ZR layer navigation panel/bottom panel/close/sidebar (with Claude
adapters); Plus new chat; R hold/release dictation; ZR Fn; right stick arrows in
both layers; right stick click, Home and SL/SR disabled. App switching uses
three quick ZL taps. Scroll, horizontal cursor movement and Backspace repeat while held;
app/prompt switches require neutral controls before continuing.

Triple-ZL timing: each press lasts at most 300 ms, the release-to-next-press
interval is at most 350 ms, and all three taps complete within one second. Switch
only on the third release. A long hold, another control, mode/focus transition,
disconnect or desktop restoration clears partial counts. Fn responds immediately
without waiting for this timing window. The old ZL+Capture chord is consumed with
either release order and never becomes an ordinary Capture tap.

2026-10-25 audit: the user's current View-menu screenshot distinguishes
previous/next **sidebar item** (`Cmd+Option+[` / `]`) from previous/next **tab**
(`Cmd+Shift+[` / `]`). Physical old chords also failed to change the user's chat.
Sidebar uses `Cmd+Shift+S` (`Cmd+B` remains documented as an alias); navigation
panel uses `Cmd+Shift+E`. `Cmd+Option+B` now switches between Chat and tabs.
New/close/bottom-panel/chat-1 bindings match current OpenAI documentation.
Dictation/effort bindings are retained without claiming new native acceptance.
`Cmd+Shift+A` archives; it does not stop. No archive action was executed.

0.2.8 adapts only exact known bindings when reading/resetting the legacy
baseline into the ChatGPT target. Saved target profiles and nonmatching custom
actions remain authoritative. The original file and Claude profile are unchanged.

Desktop-only actions use documented shortcuts or accessible controls; CLI
bindings must not be substituted. Unavailable controls produce visible errors.
For Claude input selection, hold ZL before a fresh left/right stick movement,
then release both. A direction already held before ZL does not select a pane.
Two visible side-by-side prompt frames are required; AX traversal order is not
used as left/right order, and a missing/ambiguous pane blocks selection. The
gesture is reserved in the shared session without rewriting either profile.
Selection cancels delayed taps/repeats and releases recording in the old input
before focusing the new one, then requires neutral controls. Failed cleanup
blocks focus; explicit pane selection can retry after a prompt-readiness failure.
L, scrolling and Capture's effort menu use the selected prompt. A remembered
selection is scoped to its process/window and must still be present and visible;
an identifiable manually focused prompt takes precedence. Test Mode only previews.
Claude owns native recording/transcription and its microphone permissions; the controller
never records audio or injects transcribed characters. The active Claude prompt must
expose Hold to record, and release/switch sends mouse-up before refocusing the input.
Claude's Code-page, prompt, pane and effort controls require validation against
the locally installed version. Arbitrary custom keyboard mappings remain
target-local; they are not silently treated as semantic commands.

## Desktop readiness and scrolling

On Claude activation, the driver requests Electron's documented
`AXManualAccessibility` support and waits for the web tree. Unavailable controls
produce a readiness error; Code-page and unambiguous-prompt checks remain intact.
The controller uses Claude's native Hold to record and model/effort controls,
not a speech engine or terminal shortcut substitution.

Codex/ChatGPT scrolling identifies a focused or unique visible text input
independently of Claude's label strings. Rich-text inputs need no AXValue write
support. The semantic path chooses an accessible region above that input in its
column, handling negative-origin displays and nested regions. Cached anchors
are scoped to process/window/input/region.

If the semantic path is unavailable, compatibility routing uses the original
controller point at window center X and 42% of its height, inside the verified
foreground target window. Invalid windows or dimensions at most 300 pixels block
this fallback. It does not depend on cursor position or activate another app.
Complex multi-pane placement still needs native validation. Claude's existing
pane-aware scroll route is unchanged.

Wheel events clear inherited modifier flags. Feedback identifies `mode=ax` or
`mode=legacy-window`, geometry, role counts/path and event flags without chat
content. Errors survive release events until successful output/recovery. A
resolved mapping or a posted event does not prove visible page movement.

## Desktop layout and connection HUD

Use **记录当前桌面布局** to select one ordinary, non-minimized window per app.
Multiple candidates require explicit selection; a visible app may expose more
WindowServer windows than expected. Capture stores process/window identity,
desktop UUID, display identity and frame in the unified preferences. Desktop
numbers are descriptive, not hardcoded destinations. Geometry on inactive
desktops comes from WindowServer without reading window titles/content.

Live controller arrivals, including startup with a connected device, restore the
saved layout. Rescans and battery changes do not trigger another connection
edge. Restore cancels active output and consumes controls through completion
and the neutral barrier. Test Mode pauses both automatic and manual movement.
**恢复已记录布局** retries manually; **预览连接 HUD** previews without moving.

The HUD text is exactly **vide coding mode on**. It appears for three seconds on
the pointer's screen, ignores mouse input and does not activate the controller.
A subtitle distinguishes Test Mode and incomplete restoration.

Restoration uses dynamically resolved private macOS Spaces symbols on macOS
14.5+, with desktop/frame verification after movement. It uses existing
Accessibility permission, without a helper or SIP changes. It may briefly
activate apps to resolve accessible window handles and then return prior focus.
A failure after one move can leave a partial restore.

Deleted destinations, changed displays, fullscreen/minimized windows or ambiguous
matches need correction or re-recording. A missing selected window in the same
process is never substituted. After app restart, matching is automatic only
when one candidate exists. Missing apps are not launched; tabs/conversations
are not restored. Re-record after closing the selected window.

## Verification status

Historical candidate checks (2026-10-25), followed by the current gesture update:

| Check | Evidence and limits |
| --- | --- |
| Automated | 114 tests in 19 suites passed; covers transitions, cleanup, profile isolation, shortcut adaptation, connection edges, window matching, accessibility readiness and scroll geometry |
| Packaging | Release build, strict signature and archive checksum passed; local installed executable matched the staged release |
| OpenSpec | Strict validation not run: CLI unavailable |
| Claude panes | User reported 0.2.3 left/right selection, recording in each input, stop-on-release and right-conversation scrolling passed |
| Claude readiness fix | Native focus reported ready; user reported 0.2.7 L hold/release recording passed |
| Codex/ChatGPT shortcuts | User reported 0.2.8 ZL+stick chat navigation and ZL+D-pad sidebar/navigation panels passed |
| Codex/ChatGPT scrolling | User reported 0.2.11 stick up/down and stick-click-to-bottom passed; the successful routing mode was not independently established |
| Saved layout | User reported successful capture; saved selections identified desktops 5/6 in the local setup |
| Pending physical checks | Reconnect/launch restoration and HUD, complex multi-pane fallback placement, right-controller coverage and fresh Capture single/double/app-switch confirmation |

Earlier 0.2.9/0.2.10 scroll probes failed; they are not acceptance of the final
fix. User-reported physical acceptance is distinct from tool-observed native
state and unit tests. Results on older candidates do not certify every gesture
on 0.2.11. Codex native UI inspection was unavailable to the computer-use tool;
its output checks above came from the user's physical tests.

0.3.0 validation: **128 tests in 19 suites passed**, including 48 unified
transition/profile tests. 0.3.0 adds configurable long-press actions; in Claude
Code, holding D-pad right for 2 s sends `⌘Return` (user-confirmed physically).

0.2.12 validation: **122 tests in 19 suites passed**, including 42 unified
transition/profile tests. Release/signature/archive checks and the new gesture
physical acceptance are recorded separately. Earlier native acceptance is
retained as historical evidence. The user confirmed the 0.2.12 triple-ZL
round trip from Codex to Claude Code and back.

The 0.2.12 candidate was backed up and installed at the canonical `/Applications`
path on 2026-10-28. Its running binary matches the staged signature/hash, and
the new gesture label and connected left Joy-Con are visible in the native UI.
Original configuration and saved coding-desktop layout checksums are unchanged.
Only the candidate's Accessibility identity was refreshed. After the user
completed local macOS unlock, System Settings showed its switch on, and clicking
Request / Refresh produced `Accessibility permission granted` in the candidate.
After waking/reconnecting the controller, the user replied `OK，可以了。`
to the requested triple-ZL round trip (Codex → Claude Code → Codex). This is
user-reported physical acceptance. Capture/Fn boundary preservation is covered
by the automated regression tests, not newly claimed native acceptance.
The installed binary, original configuration and saved layout were reverified
unchanged after this test.

Code/release changes follow [the final validation procedure](Maintenance.md).
Permissions/upgrades follow [Accessibility-Upgrades.md](Accessibility-Upgrades.md).

References: [Electron macOS accessibility](https://www.electronjs.org/docs/latest/tutorial/accessibility),
[ChatGPT command reference](https://learn.chatgpt.com/docs/reference/commands).
The recorded native View-menu screenshot, rather than a generic shortcut list,
established the sidebar-chat/tab distinction for the tested application.
