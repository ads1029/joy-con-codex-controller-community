# Unified desktop controller (development candidate)

Approved scope (2026-10-22): one menu-bar application, the existing single-left
portrait layout, Codex and the **Code page in Claude Desktop**, and
**ZL + Capture** to switch targets. SL/SR remain disabled. Plain Capture keeps
its imported single/double-tap shortcuts. The unified candidate uses its own
canonical installation and must not overwrite the original controller/configuration.

## Architecture and ownership

One GameController/HID adapter owns device input. The existing mapping engine,
hold ownership, repeat policy and tap recognizer remain shared. A target switch
gate intercepts ZL + Capture before double-tap recognition. Each desktop target
has a separate profile, application identity, focus/Code-page validation and
scroll destination. Berrry Joyful was inspected as prior art; this implementation
uses the existing controller core, with no second controller process or copied
Berrry speech engine. Existing upstream attribution remains applicable.

Switching first cancels delayed taps/repeats and releases held shortcuts to the
old destination. Input remains suppressed until all held controls return to
neutral and the destination is ready. Failed focus/permission checks never
fall through to another application. Test mode changes the displayed target
without activating applications or sending keyboard/mouse events.

Changing Test Mode clears delayed output and releases old holds, then accepts
fresh input after controls return to neutral. Manually focusing the selected app
is sufficient; a stick movement or Focus-button click is not required to arm L.
The emitter still validates permissions and the selected foreground app on every
new output. Failed cleanup leaves output suspended with a visible error.

Activation uses target-specific completion rules. Codex requires permission and
its foreground bundle identity; keyboard/hold readiness does not depend on the
Claude prompt-label matcher. Claude still requires Code-page confirmation and
an unambiguous active prompt. Conversation scrolling keeps its separate AX pane
checks; successful application activation is not proof of scroll acceptance.

The outer Claude page URL takes precedence over Code selector state. A missing
radio-button value must not reject `/code` or `/epitaxy/`; a Chat URL must not
pass because of a stale selected value. Cached page references have their URL
read again on every check. Focus failures remain visible after suppressed inputs
until the next activation or output-state reset.

## Isolation

Connection layout (0.2.5): record one selected ordinary window per app with
**记录当前桌面布局**. Live-mode controller arrivals restore saved desktop UUIDs
and window frames; Test Mode only shows the connection HUD. The exact HUD text
is **vide coding mode on**, dismissed after three seconds without activation or
mouse capture. Rescans/battery refreshes do not trigger it. Restoration releases
holds and consumes input until completion plus neutral controls. Private Spaces
symbols are resolved dynamically; missing destinations, fullscreen/ambiguous
windows and failed post-move verification are errors. Multiple windows are
supported through explicit per-app window selectors. The snapshot retains the
selected process/window identity: a missing window in the same process is never
substituted; restarted apps only match automatically with one candidate window.
No SIP changes or helpers
are used. A failure after one window moves may leave a partial restore. Use
**恢复已记录布局** to retry and **预览连接 HUD** to preview. New native behavior
requires separate acceptance from automated routing tests.

- Product/app: `JoyConUnifiedController` / `JoyConUnifiedController.app`.
- Bundle identity: `com.ads1029.JoyConUnifiedController`.
- Preferences: dedicated `com.ads1029.JoyConUnifiedController` domain: bundled runs use their own standard defaults; CLI runs use a named suite. Unavailable defaults remain in memory, never fall back to another host domain.
- Profiles: `~/Library/Application Support/JoyConUnifiedController/` (separate Codex/Claude files).
- Existing `JoyConCodexController/mapping-profile.json` is read only as the
  initial Codex layout when no unified profile exists. Import never writes back.
- The old installed app, old preferences and source profile are not replaced.
- SL/SR and the target-switch chord are reserved independently of profile edits.
- Only one controller application may produce live output at a time.

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
| Capture single | Increase effort (ChatGPT `Ctrl+Option+Right`, Claude model menu) | Switch app | Switch app |
| Capture double | Decrease effort (ChatGPT `Ctrl+Option+Left`, Claude model menu) | Reserved switch combination | Reserved switch combination |
| ZL | Enter Fn while held; no keyboard event | — | — |
| SL/SR | Disabled | Disabled | Disabled |

Right-controller retained mappings: A/B/X/Y ordinary Enter/Escape/side chat/
Backspace; ZR layer navigation panel/bottom panel/close/sidebar (with Claude
adapters); Plus new chat; R hold/release dictation; ZR Fn; right stick arrows in
both layers; right stick click, Home and SL/SR disabled. App switching uses
ZL+Capture. Scroll, horizontal cursor movement and Backspace repeat while held;
app/prompt switches require neutral controls before continuing.

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

## Verification and delivery gates

- Focused tests: chord priority/order, single/double Capture preservation,
  duplicate edges, neutral barrier, in-flight tap/repeat cancellation, holds
  released before target changes, test-mode suppression, and disabled SL/SR.
- Persistence tests: separate target paths, read-only legacy import, invalid
  profile recovery and proof the legacy bytes remain unchanged.
- Desktop policy tests: target isolation and localized Code/prompt/scroll
  matching. Native integration checks must be reported separately from mocks.
- Final checks: `swift test`, OpenSpec strict validation when available,
  release build, signature and archive checksum verification.
- Physical acceptance: connected single-left Joy-Con, both desktop apps,
  listening while switching, Fn/repeat/double-tap boundaries and reconnect.
  A build passing tests is not proof of hardware or permission acceptance.

Current status: **0.2.11 installed and running** at the approved canonical
`/Applications/JoyConUnifiedController.app` path, still a development candidate.
The user reports successful physical tests of right/left input selection,
L recording in each input with stop on release, and right-conversation scrolling.
Capture single/double and application-switch preservation pass automated
regressions; no separate physical confirmation of those controls on 0.2.3 was
reported. The previous candidate is backed up, and all four protected original
controller/configuration hashes remain unchanged.

0.2.4 adds connection HUD/layout restoration. The 99-test suite and release
build pass. Initial native capture exposed empty AXWindows on an inactive Codex
desktop; capture now uses WindowServer geometry without window titles/content,
and restore resolves AX handles (briefly activating an app if necessary) before
moving either window. Native snapshot, cross-desktop restoration and physical
reconnect acceptance for this addition remain pending. The prior physical
acceptance below applies to 0.2.3's controller mappings, not these new features.

0.2.5 fixes the observed `Codex ... found 4` capture failure with per-app
window selection and persistent window identity. Four focused regressions cover
multiple windows, closed-window refusal, restarted apps and old snapshots.
The full suite passes 103 tests in 17 suites. The user reported successful
recording, and native inspection confirmed the saved selection is Codex desktop
5 (window 22363) and Claude Code desktop 6 (window 21022), both 1440×2535 at
(-1440, -462), with Accessibility granted. Actual restoration and physical
reconnect/HUD acceptance remain pending.

0.2.6 changes only the HUD wording to the user's exact `vide coding mode on`.
The existing saved layout is retained; no additional behavior tests are needed
for this text-only change. Release build/signature/checksum checks apply.
The installed binary matches the staged release, saved desktop selections are
unchanged, and the existing Accessibility authorization has been renewed and
confirmed granted in the running app. No new physical reconnect acceptance was
reported during this wording update.

0.2.7 addresses Claude Desktop 3.6556.2 exposing only its native AX window shell.
The controller requests Electron's documented `AXManualAccessibility` attribute
at Claude activation and waits for the web tree before inspecting Code controls.
An unavailable tree fails with a dedicated error and the AX request result;
Code/Chat routing and unambiguous-prompt checks remain enforced. Three focused
readiness tests cover delayed exposure, timeout and already-ready trees. Full
suite: 106 tests in 18 suites pass; release/signature/archive checksum pass.
Native before/after inspection confirms the previously empty window shell now
exposes the `claude.ai/epitaxy/` Code page, selected Code radio, two prompt areas
and two Hold to record controls. The controller's actual Focus action completes
with `Claude Code ready`. Existing desktop 5/6 selections remain saved and the
controller's Accessibility permission is granted. No recording or message was
started during native inspection. The user subsequently confirmed physical
L press/hold starts recording and release stops it normally on 0.2.7. This is
user-reported hardware acceptance of the repaired Claude activation/recording
path; no new per-pane scrolling or Capture acceptance was reported in this check.

Reference: [Electron third-party macOS accessibility](https://www.electronjs.org/docs/latest/tutorial/accessibility).

0.2.8 shortcut repair: 108 tests in 18 suites pass, including import/session
regressions for the actual ZL/vertical-stick chord, unchanged ordinary scrolling,
Claude isolation, custom-action preservation and byte-identical legacy source.
Release build, installed signature and ZIP checksum pass. The running native
mapping list shows `Cmd+Option+[` / `]`, `Cmd+Shift+S` and `Cmd+Shift+E` at the
correct controls, and Accessibility is granted. Installation preserved the
saved desktop selections and legacy profile SHA-256
`8058c5a34ce8b2285e94963cfc6bfe754c14ff1164ec00231005c63acf6869a8`.
The user subsequently confirmed all three physical checks succeed: ZL+vertical
stick changes ChatGPT chats, ZL+D-pad left toggles the sidebar, and ZL+D-pad
right toggles the navigation panel. This is user-reported hardware acceptance.
OpenSpec CLI is unavailable, so strict validation was not run.

Reference: [ChatGPT commands](https://learn.chatgpt.com/docs/reference/commands),
plus the user's current native View-menu screenshot for the sidebar/tab distinction.

0.2.9 separates ChatGPT conversation scrolling from Claude's prompt-label
matcher. It selects a writable focused/unique input, validates a real accessible
conversation/scroll region in that input's column, and scopes its cache to the
process/window/input. No current-pointer or blind window-center fallback is
used. Electron web accessibility is requested on first use per process. Missing
or ambiguous input/regions block output with a specific error; mapping failures
survive release events until a successful output/recovery. Claude's existing
scroll routing and 0.2.8's Fn navigation remain unchanged. Geometry regressions
cover adjacent sidebar/browser panes, split chats, negative display origins,
nested scroll regions and unavailable/ambiguous targets. Native scroll
acceptance remains pending this candidate. Full suite: 112 tests in 19 suites
pass; release build, installed signature and ZIP checksum pass. The canonical
installed executable matches the staged release. Existing desktop 5/6 selections
and original profile bytes are preserved, and the running app confirms
Accessibility is granted. No agent-driven ChatGPT scrolling was performed.

The user subsequently reported 0.2.9 still does not scroll, even with the real
pointer over conversation text. Released-action feedback was initially mistaken
for successful dispatch; the later retained error disproved that interpretation.
This disproves accepting geometry/unit checks as a completed
native fix; the scrolling bug remains unresolved. 0.2.10 adds transient,
content-free geometry/event/hit-role diagnostics and clears wheel modifiers to
separate bad coordinates from dispatch behavior. It is a diagnostic candidate,
not native acceptance. Independent review could not start because the configured
subagent route `jev/auto` is unavailable.
The 112-test suite, release build, installed signature and archive checksum
pass. Installation preserves the original profile bytes and saved layout;
the running app confirms Accessibility permission is granted. The next required
evidence is the physical scroll probe's point/rectangles/hit-role/flags output.

0.2.10 physical diagnostics actually report input-anchor failure before wheel
dispatch (`editable input is unavailable or ambiguous`). The earlier released
action text was not sufficient evidence of dispatch. 0.2.11 removes AXValue
settable gating: a focused/unique text input can anchor scrolling without
supporting direct accessibility value writes. It prefers a unique text area over
unfocused search/address text fields. When ChatGPT cannot expose an input or
semantic scroll area, it uses the original controller's center-X/42%-down point
inside the verified foreground target window; invalid/small windows still block.
The `mode=ax` / `mode=legacy-window` diagnostic includes focus/input role counts.
This intentionally replaces 0.2.9's strict no-fallback rule for ChatGPT only.
It preserves the existing window-relative behavior without depending on the
physical cursor or activating another app. Multi-pane placement and actual
scrolling initially required native acceptance. Claude's path is unchanged.
The updated 114-test suite, release build, signature and archive checksum pass.
The installed executable matches the release; the saved layout and legacy
profile bytes are preserved. The running app confirms Accessibility is granted.
The user subsequently confirmed all 0.2.11 physical checks pass in ChatGPT:
ordinary stick up/down scrolls and stick press scrolls to the bottom. This is
user-reported hardware acceptance; it does not establish which routing mode
was used or independently verify complex multi-pane placement.

## Verification record

Entries retain the sequence of earlier repairs; pending states in historical
entries are superseded by the current acceptance summary above.

- Final full suite: **97 tests in 15 suites passed**, including 32 unified
  transition/isolation/policy/startup regression tests.
- Physical input was subsequently confirmed: Bluetooth and GameController
  enumerate Joy-Con (L), and the user reports Joy-Con ready with Recent input
  changing on presses. This confirms input receipt, not desktop output.
- Live-mode testing exposed a startup-state bug: disabling Test Mode suspended
  the session until a Focus-button/stick activation, so a manually focused Codex
  window could not receive a fresh L press. The mode transition now re-arms only
  after successful cleanup, retaining the neutral barrier and emitter destination
  checks. Three regressions cover fresh L, held preview controls and failed cleanup.
  Running copies must be quit and reopened from the repaired package to test it.
- The user confirmed that physical Control+Shift+D starts Codex voice input,
  narrowing the reported L failure to the controller path rather than an invalid
  Codex shortcut. The user then quit the candidate for replacement. The rebuilt
  package still needs a fresh physical L press/release acceptance check.
- Runtime permission repair confirmed an old ad-hoc code requirement and cached
  deleted `dist` URL in TCC logs. Only the unified identity's Accessibility grant
  and application registration were refreshed; the user completed the system
  authentication. New process 26782 returned Accessibility preflight `authValue=2`
  with no error. The user then confirmed stick activation raises Codex.
- The user isolated the next failure using the Focus button: `Select the intended
  prompt; multiple panes or no accessible prompt were found`. Application
  activation was succeeding while the shared Claude-style prompt matcher kept
  the session suspended. Version 0.2.1 removes that matcher from Codex activation
  completion, retains permission/foreground checks, and preserves Claude's
  Code-page/prompt gate. Three new regressions cover these target boundaries.
  Actual L recording start/release remains pending the repaired build's test.
- Approved 0.2.1 update: the canonical executable matches the staged binary and
  archive. System Settings now exposes JoyConUnifiedController with its
  Accessibility switch on. No original-controller bundle or configuration hash
  changed. Installation/permission receipts are under the unified support folder.
- The user's reply to the 0.2.1 Codex focus/hold/release check was `oklee`,
  provisionally interpreted as success, not independently observed or confirmed
  per step. Claude acceptance remains blocked: the user reports `Claude Code is
  not ready. Use the Focus button to retry; no input was sent.` The running
  `/Applications/Claude.app` bundle identifier matches the configured target
  (`com.anthropic.claudefordesktop`), so the desktop application identity is
  correct. Native inspection still exposes two prompts and a focused web area.
  Prompt ambiguity is a hypothesis pending the Focus button's original error;
  later suppressed controller events overwrite that error with generic not-ready
  feedback. No new build, installation or permission change was performed.
- The Focus-button retry subsequently isolated `Claude's Code page is not ready`.
  The 0.2.1 implementation returned a missing/false Code radio value before
  consulting the outer Code URL. The next candidate removes that early return,
  reads URL or string AX URL values, and retains activation errors across later
  suppressed inputs. Its native acceptance remains pending; the running 0.2.1
  bundle is preserved while the repair is prepared.
- Version 0.2.2 was staged with a verified ad-hoc signature and archive checksum.
  The 25 focused unified tests and the full 90-test suite pass; release
  compilation passes. After the user quit 0.2.1, the approved candidate-only
  update preserved that bundle under `UpgradeBackups/20261023_040507-0.2.2`,
  installed the exact staged binary at `/Applications/JoyConUnifiedController.app`
  and verified its signature/hash. Process 51017 is running the canonical 0.2.2
  executable. Only this candidate's Accessibility service was reset; System
  Settings now shows its switch on. The controller's refreshed trust status,
  Claude page readiness and physical output acceptance remain pending. The four
  original-controller file hashes remain unchanged.
- The user confirmed the 0.2.2 Focus retry succeeded, then requested controller
  selection of the right-hand discussion input. Version 0.2.3 adds Claude-only
  ZL + stick left/right selection; 0.2.2 and all configuration files were
  preserved during package preparation, with native tests pending at that stage.
- The 0.2.3 automated checks cover pane geometry, non-retroactive ZL ordering,
  cleanup before focus, failed cleanup recovery, readiness recovery, stale
  activation, preview isolation, and preserved recording/Capture/application
  switching after pane selection. Native focus/recording is not inferred from
  these tests. Independent review remains unavailable (`jev/auto` route failure).
  Release compilation, ad-hoc signature verification and ZIP CRC/binary/mode
  checks passed. After the user quit the candidate, 0.2.2 was backed up under
  `UpgradeBackups/20261023_041813-0.2.3/previous-bundle` and the exact 0.2.3
  staged binary was installed at the canonical `/Applications` path. Process
  57434 is running the verified executable. Only the candidate's Accessibility
  service was reset, and its System Settings switch is now on. The user then
  replied `测试已经成功。` to the requested Refresh/right selection/right L
  hold-release/right scroll/left selection/left L test sequence. These are
  user-reported native acceptance results, not tool-observed recordings. The
  four original-controller file hashes were reverified unchanged afterward.
- Follow-up verification covers raw HID L/ZL plus portrait Home/Capture through
  the unified session, releasing ZL before Capture after switching, a fresh
  ordinary Capture after the neutral barrier, and a second Capture held beyond
  the original single-tap deadline. These are adapter-mapping/session tests,
  not physical-device or native mouse-event acceptance.
- Mapping output failures now display their actual reason in the feedback area;
  an inaccessible scroll pane or recording control must not appear successful.
- Claude Desktop 3.1623.3 native keyboard-help panel inspected: Cmd+B sidebar,
  Cmd+J terminal, Cmd+1…9 session jump, Cmd+Shift+[ / ] session cycling, Cmd+;
  side chat, Cmd+Shift+D Changes. Claude's actual model menu and effort submenu
  expose selected values; the existing dictation setting was Hold to record.
- No message sent, recording started, effort value selected or permission granted
  during those checks. Both inspected menus were dismissed.
- Codex native UI inspection was refused by the computer-use tool. Do not claim
  native Codex or hardware acceptance from source/unit checks.
- Independent subagent review was unavailable: configured `jev/auto` was rejected
  by the subagent service. Main-thread source review and tests remain the evidence.


- First native preview exposed a same-bundle `UserDefaults(suiteName:)` nil
  initialization crash. It was fixed using the application's own standard domain,
  with a dedicated named suite only for CLI hosting and no force unwrap.
  [Foundation's initializer contract](https://developer.apple.com/documentation/foundation/userdefaults/init(suitename:))
  explicitly excludes the application's own bundle identifier from suite names.
- The repaired release was rebuilt and launched from `dist`, remaining alive
  for multiple minutes without a new crash. The computer-use native pipe then
  closed; retry and session reset did not restore UI access. Window rendering,
  menu clicks and real controller/native-output acceptance remain **unverified**.
- The preview was stopped after this check. No installation or permission grant
  was performed. The ZIP, signature and old-profile/app hashes are recorded in
  `dist/unified-verification.json`.
- Follow-up native inspection restored access to Claude's UI and confirmed that
  the installed Code page still exposes two independently labeled conversation
  and prompt areas plus Hold to record controls. The repaired candidate's own
  window and actual Joy-Con chords, scrolling, recording and release remain pending
  native-output acceptance; connection and basic input receipt are separately
  confirmed above. Do not infer output acceptance from the native UI labels.
- OpenSpec CLI is not installed; strict validation was **not run**. Shell syntax
  and Git whitespace checks passed. The new specification remains reviewable.
