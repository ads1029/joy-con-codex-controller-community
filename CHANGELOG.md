# Changelog

Changes in the Community fork are recorded here. Candidate versions describe
local development/testing, not proof of a published or notarized release.
The current release is **0.3.0**; the historical maintenance baseline is
**0.1.12**. See [NOTICE.md](NOTICE.md) for attribution/license status.

## 0.3.7 — development candidate

- Rename the application to **JoyRelay**, including its macOS Accessibility
  entry. The installer migrates the prior bundle filename without changing the
  bundle identifier, executable name or profile paths.
- Include the MIT license and upstream attribution notice in the binary archive.
- Keep the GitHub repository name and upstream attribution intact.

## 0.3.6 — development candidate

- Add the Switch Pro right-hand layout: R/ZR navigate conversations; right
  stick up/down scrolls, R3 jumps to the bottom, and Claude Code left/right
  selects the prompt. The overlay does not rewrite shared mappings.
- Preserve Pro L/ZL, Capture and the existing Joy-Con paths. The Pro layout
  passed event replay; live app behavior and Pro dictation are not claimed.

## 0.3.5 — development candidate

- Recognize the first-generation Nintendo Switch Pro extended profile and
  route its Share button through the existing Capture recognizer.

## 0.3.4 — local candidate

- Parse L/ZL/L3 from full 0x30–0x33 and simple 0x3F input reports, rather
  than relying on HID element callbacks absent in the observed full-report mode.
- Merge report and legacy value callbacks into one deduplicated edge source;
  ignore stale command replies for buttons and release held state on disconnect.
- Retain report-mode/L/ZL press-count diagnostics. The Codex native-shortcut
  route and all saved profiles are unchanged.

- Record the diagnosis in the [debugging log](Docs/Debugging-Log.md). The local
  0.3.4 build passed 143 tests and received physical confirmation that L
  dictation works on a left Joy-Con.

## 0.3.3 — local candidate

- Prefer Codex's existing native hold-to-dictate shortcut when configured.
  Emit modifier-down/up as well as main-key events so the OS-global hold and
  release listener can observe the full gesture, without AX button lookup.
- Preserve the most recent voice diagnostic independently of stick feedback.
- Keep Claude's voice route and all saved mappings unchanged. Physical voice
  acceptance is separate from tests and successful event emission.

## 0.3.2 — local candidate

- Repair Codex microphone discovery when the desktop host exposes Chromium's
  AXEnhancedUserInterface instead of Electron's AXManualAccessibility. Wait
  without blocking controller input, and cancel preparation on L-up.
- Match the microphone's title, description and help, ignore unavailable
  duplicates, and keep stop/transcribe scoped to the original composer.
- This is a local build; physical recording acceptance is tracked separately.

## 0.3.1 — local candidate

- Restore L-button dictation for current Codex and Claude Code desktop apps.
  Codex uses its native composer microphone instead of the browser-only
  shortcut, and Claude Code recognizes the updated Chinese prompt labels.

## 0.3.0 — first community release

- Add configurable long-press actions (default 2 s, 500–5000 ms) in the mapping
  editor. A control with a long press sends its short action on release; holding
  past the threshold sends only the long-press action, without a later short tap.
  Fn-layer actions are unchanged, and app/input switches cancel pending holds.
- In Claude Code, holding D-pad right for 2 s sends `⌘Return` while the imported
  profile still maps it to plain Return.
- Adopt MIT for this fork following upstream permission confirmed by Minjie Huang
  on 2026-10-28; retain upstream attribution and update licensing documentation.
- Refresh public documentation for the unified identity, installation paths,
  imported mappings, supported targets and current acceptance limits.
- Add contribution/security guidance, attribution notice and issue/PR templates.
- Validation: 128 tests in 19 suites passed, including 48 focused unified tests.
  The Claude D-pad-right long press passed a user-reported physical check.
  First release published by the tag workflow: ad-hoc signed, not notarized.

## 0.2.12 — development candidate

- Replace ZL+Capture app switching with three complete short ZL taps within one
  second, switching on the third release. Long holds or other inputs cancel counts.
- Keep Fn immediate, ordinary Capture single/double, Claude pane selection,
  recording, scrolling, saved desktop layout and original configuration intact.
- Disable the former ZL+Capture chord without leaking a Capture action on release.
- Validation: 122 tests in 19 suites passed, including 42 focused unified tests.
  Release build, strict ad-hoc signature and archive checks passed. The new
  gesture passed a user-reported physical round trip between Codex and Claude Code.

## 0.2.11 — development candidate

- Allow rich-text inputs to anchor Codex/ChatGPT scrolling without direct
  accessibility value-write support.
- Fall back to the original controller's center-X/42%-down point inside the
  verified foreground target window when semantic scroll routing is unavailable.
- Keep scroll diagnostics separate from actual visible movement. The user
  confirmed ordinary stick up/down and stick-click-to-bottom work.
- Validation record: 114 tests in 19 suites, release build, signature and archive
  checksum passed; OpenSpec CLI unavailable. Complex multi-pane fallback
  placement and physical reconnect/layout/HUD acceptance remain pending.

## 0.2.9–0.2.10 — diagnostic candidates

- Separate Codex/ChatGPT scroll targeting from Claude's prompt-label matcher.
- Preserve output errors across release events; add geometry/role/flag diagnostics
  and clear inherited wheel modifier flags.
- Physical tests still failed; these candidates did not resolve scrolling.
  Later feedback isolated an unavailable/ambiguous input anchor before dispatch.

## 0.2.8 — shortcut compatibility

- Adapt exact known imported Codex Fn bindings: previous/next sidebar chat use
  `Cmd+Option+[` / `]`, sidebar uses `Cmd+Shift+S`, navigation uses `Cmd+Shift+E`.
- Preserve saved target profiles, unrelated custom shortcuts and Claude bindings.
- Correct the `Cmd+Shift+A` description to Archive chat.
- User confirmed chat navigation and both panel shortcuts physically.

## 0.2.7 — Claude readiness

- Request Electron web accessibility and wait for Claude's Code tree before
  checking selectors and prompts, retaining Code-page and ambiguity checks.
- User confirmed L hold starts recording and release stops it.

## 0.2.4–0.2.6 — desktop layout and connection HUD

- Record one selected ordinary window per app, with desktop/display identity,
  geometry and process/window matching; restore on live controller arrival.
- Support explicit selection when WindowServer exposes multiple windows.
- Show a three-second nonactivating HUD; final wording is **vide coding mode on**.
- Saved-layout capture was confirmed. Physical reconnect/restore/HUD acceptance
  remains separate from automated matching and connection-edge tests.

## 0.2.0–0.2.3 — unified controller

- Add isolated Codex/Claude profiles, read-only legacy import, ZL+Capture target
  switching, input cleanup/neutral barriers and reserved SL/SR controls.
- Add Claude Code validation, native hold-to-record and model-menu effort routing.
- Add ZL+fresh stick left/right for Claude's two-pane input selection.
- Repair activation/readiness and preferences handling. User confirmed pane
  selection, recording in each input and right-conversation scrolling on 0.2.3.

## 0.1.12 — historical maintenance baseline

- Supplement single-left Joy-Con stick-click input using raw HID usage 11 while
  preserving existing Default/Fn mappings and avoiding extended-gamepad duplicates.
- Retain the upstream single-Joy-Con foundation and the fork's earlier battery,
  input, scrolling, repeat and packaging improvements. See Git history for detail.
