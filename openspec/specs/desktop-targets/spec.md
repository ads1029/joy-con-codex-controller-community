## Purpose

Specify unified Codex / Claude Desktop Code routing and configuration isolation.

## Requirements

### Requirement: Resolve ChatGPT scrolling independently of Claude prompts
ChatGPT scroll output SHALL prefer a selected/unique text input and a verified
accessible conversation/scroll region above that input's column. It SHALL NOT
require Claude-specific prompt labels or direct AXValue assignment support.
When semantic routing is unavailable it MAY use the original controller's
center-X/42%-down point within the verified foreground ChatGPT window, with an
explicit legacy-mode diagnostic. Invalid windows SHALL block output. Neither
path SHALL rely on the current cursor or activate another application.
Claude split-pane routing and Fn navigation SHALL remain unchanged.

#### Scenario: Scroll ChatGPT with adjacent sidebar and browser panes
- **WHEN** ordinary stick up/down targets ChatGPT's selected input
- **THEN** wheel output is routed to that input's conversation column
- **AND** unrelated sidebar/browser regions are rejected
- **AND** an output failure remains visible after the stick is released

### Requirement: Separate ChatGPT sidebar navigation from tab navigation
When importing/resetting the legacy baseline for ChatGPT, known Fn stick-up/down
bindings SHALL use `Cmd+Option+[` and `Cmd+Option+]` for sidebar items/chats,
rather than `Cmd+Shift+[` / `]` tab navigation. Known Fn sidebar/navigation-panel
bindings SHALL use `Cmd+Shift+S` / `Cmd+Shift+E`. Custom actions, saved target
profiles, the original profile bytes and Claude's bindings SHALL be preserved.

#### Scenario: Navigate chats with ZL and the vertical stick
- **WHEN** a fresh stick up/down press follows ZL in the imported ChatGPT layout
- **THEN** exactly one corresponding sidebar-navigation chord is emitted
- **AND** ordinary vertical-stick conversation scrolling remains unchanged

### Requirement: Restore recorded desktops on controller connection
Supported-controller arrivals SHALL show a nonactivating, click-through
three-second HUD with text `vide coding mode on`. In live mode the app SHALL
restore recorded Codex/Claude desktop UUIDs and window frames, verifying the
result and displaying any failure. Recording SHALL select one ordinary window
per app, supporting multiple open windows through explicit choice. Both selected
windows/destinations SHALL be validated before the first move.

#### Scenario: Multiple application windows
- **WHEN** an app has several candidate windows
- **THEN** recording requires explicit selection and saves that process/window identity
- **AND** restoration moves only the recorded window
- **AND** a missing selected window in the same process requires re-recording
- **AND** a restarted app is matched automatically only when one candidate remains

#### Scenario: Reconnect after moving an application
- **WHEN** a supported Joy-Con arrives in live mode with a saved layout
- **THEN** held output is released and window restoration runs with input gated
- **AND** controls held during restoration require release before fresh output

#### Scenario: Repeated discovery and Test Mode
- **WHEN** discovery or battery reporting updates an already connected controller
- **THEN** no connection HUD or layout restoration repeats
- **AND** a genuine arrival in Test Mode shows a preview subtitle without moving windows

#### Scenario: Saved desktop is missing
- **WHEN** a saved desktop UUID or display is no longer present
- **THEN** restoration reports an error before moving either window
- **AND** it does not substitute a different desktop with the old ordinal number

### Requirement: Switch targets with three complete ZL taps
The unified controller SHALL switch targets only on the third ZL release in an
isolated triple tap. Each press SHALL last at most 300 ms; adjacent taps SHALL
have at most 350 ms between release and next press; all three SHALL complete
within one second. SL/SR and the former ZL+Capture chord SHALL remain disabled.

#### Scenario: Three quick ZL taps
- **WHEN** the user completes three isolated ZL taps within those bounds
- **THEN** the target toggles once, delayed taps/repeats are discarded, held
  output cleanup and destination readiness still apply, and no Capture action emits

#### Scenario: ZL is used as Fn or a sequence is interrupted
- **WHEN** ZL is held, combined with another control, or a partial sequence crosses
  suspension, disconnect or desktop restoration
- **THEN** the triple-tap count is cleared and Fn actions remain immediate
- **AND** single/double taps, duplicate edges and overlong sequences do not switch

#### Scenario: Former switch chord
- **WHEN** ZL+Capture is used and released in either order
- **THEN** it neither switches targets nor leaks an ordinary Capture single/double

#### Scenario: Plain single and double Capture
- **WHEN** Capture is used without ZL
- **THEN** the imported single/double actions and double-tap interval are retained

### Requirement: Cancel output across transitions
The system SHALL cancel delayed taps and repeats, release old held shortcuts,
and require neutral controls plus successful destination readiness before output.
Failed release or focus SHALL block output, and stale activation callbacks SHALL
not re-arm a newer transition. Test Mode SHALL not focus applications or emit input.

#### Scenario: Switch while dictating and scrolling
- **WHEN** a target switch occurs with L and a stick direction held
- **THEN** the old hold is released before the target changes, repeat output stops,
  and no held control is replayed into the new target

#### Scenario: Enable live output and manually focus the selected application
- **WHEN** the user disables Test Mode, releases all controls, manually focuses
  the selected application and freshly presses L
- **THEN** a successful cleanup permits the hold without requiring a stick event
  or the controller's Focus button, while the emitter still validates permission
  and the selected foreground destination
- **AND** failed cleanup keeps output suspended rather than re-arming the hold

### Requirement: Restrict desktop destinations
Only the selected application's foreground window SHALL receive new input.
Claude SHALL be confirmed on Code rather than Chat/Cowork. Scroll and effort
actions SHALL use the active accessible conversation/prompt; ambiguity SHALL
produce an error rather than operate in a different pane.

#### Scenario: Claude is showing Chat
- **WHEN** the controller attempts new Claude Code output
- **THEN** it enters and validates Code during explicit focus or blocks output

#### Scenario: Electron initially exposes only the window shell
- **WHEN** Claude activation sees no web accessibility tree after an app restart/update
- **THEN** the controller requests `AXManualAccessibility` and waits with bounded retries
- **AND** Code selectors are inspected only after web-tree readiness
- **AND** unavailable readiness blocks input with a specific diagnostic
- **AND** existing Code/Chat routing and prompt validation remain enforced

#### Scenario: Codex has no Claude-style accessible prompt
- **WHEN** Codex is successfully activated and its permission and foreground
  bundle identity are validated
- **THEN** keyboard and held-shortcut readiness SHALL complete without requiring
  the Claude prompt-label matcher
- **AND** Claude activation SHALL still reject a missing or ambiguous prompt

#### Scenario: Claude Code selector omits its selected value
- **WHEN** the outer Claude page URL is a recognized Code route but the Code
  radio button has no accessible selected value
- **THEN** page validation SHALL accept that route and continue prompt validation
- **AND** an outer Chat URL SHALL remain blocked despite a stale Code selection
- **AND** later suppressed inputs SHALL preserve the activation failure reason

### Requirement: Select a Claude input using ZL and horizontal stick
In Claude Code, a fresh left/right stick press while ZL is already held SHALL
select the visible left/right prompt using accessible window geometry. Codex and
ordinary horizontal stick mappings SHALL remain unchanged. Test Mode SHALL
preview selection without changing native focus.

#### Scenario: Select another input while recording
- **WHEN** the user holds ZL and freshly moves the stick right during recording
- **THEN** the controller SHALL stop the old recording before focusing the right input
- **AND** discard delayed taps/repeats, require neutral controls, and route later
  recording, scrolling and effort changes through the selected prompt
- **AND** failure to release the old hold SHALL prevent the focus change

#### Scenario: Input choice is missing or ambiguous
- **WHEN** two visible side-by-side inputs cannot be identified
- **THEN** selection SHALL report failure rather than guess a location
- **AND** a later valid explicit selection MAY recover prompt-readiness failure

#### Scenario: Focus is reported at page level after selection
- **WHEN** the accessibility API reports only the whole page as focused
- **THEN** remembered selection SHALL be reused only in the same process/window
  while that input remains present and visible
- **AND** a newly identified manual input focus SHALL take precedence

### Requirement: Preserve the installed controller
The candidate SHALL have a distinct bundle ID, preference suite and per-target
Application Support paths. Initial legacy import SHALL be read only. Export and
installation helpers SHALL refuse to replace the legacy configuration or app.

#### Scenario: First launch and target-specific editing
- **WHEN** the old profile exists and no unified profile has been saved
- **THEN** the old layout is read without creating/replacing the old file, and
  later Codex/Claude edits are saved only in separate unified profile files

### Requirement: Restore an isolated baseline
For the unified executable, reset SHALL restore the legacy layout (or validated
core defaults when no legacy layout is available) into the selected unified
target only. This specializes the core profile-configuration reset contract.

#### Scenario: User resets the Claude profile
- **WHEN** reset is confirmed
- **THEN** only the Claude unified profile changes and the original Codex bytes
  and the saved unified Codex profile remain unchanged
