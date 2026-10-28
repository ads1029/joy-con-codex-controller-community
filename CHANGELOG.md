# Changelog

Changes in the Community fork are recorded here. Candidate versions describe
local development/testing, not proof of a published or notarized release.
The current candidate is **0.2.12**; the historical maintenance baseline is
**0.1.12**. See [NOTICE.md](NOTICE.md) for attribution/license status.

## Unreleased

- Adopt MIT for this fork following upstream permission confirmed by Minjie Huang
  on 2026-10-28; retain upstream attribution and update licensing documentation.
- Refresh public documentation for the unified identity, installation paths,
  imported mappings, supported targets and current acceptance limits.
- Add contribution/security guidance, attribution notice and issue/PR templates.

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
