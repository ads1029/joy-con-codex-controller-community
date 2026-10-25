# Security and privacy reporting

## Scope and support

The active development candidate is 0.2.11. There is no guaranteed response-time
or backport policy. Include the exact source revision and installed version when
reporting a problem; local candidate builds are ad-hoc signed and not notarized.

Relevant boundaries include synthetic keyboard/mouse destination checks, held
recording cleanup, Test Mode suppression, profile isolation, installer identity
checks and desktop/window selection. The app uses Accessibility and local input
frameworks. It does not implement an audio capture, speech or telemetry service;
Claude and other target apps retain their own permissions and network behavior.

## Reporting

If the repository's **Security → Report a vulnerability** private reporting option
is available, use it for sensitive details. No separate security inbox is
configured in this repository. If private reporting is unavailable, open a minimal
issue asking the maintainer to arrange a private channel, without exploit details,
private conversations, credentials, recordings or personal data.

Provide affected versions, a minimal reproduction, expected/actual destination or
permission behavior and impact. Redact local usernames/paths, window titles,
profile contents and conversation text. Scroll Feedback may contain geometry and
accessibility role names; installer receipts include local paths and process IDs.
Share only the portion needed to diagnose the issue.

## Immediate containment

Enable **Test Mode** or quit the menu-bar app to stop new mapped output. Revoking
the unified app's Accessibility grant is an additional system-level option. Do not
reset unrelated applications' permissions. Use harmless actions when validating a
fix; do not reproduce by sending private content or starting a recording in the
wrong application.

For ordinary permission/upgrade problems, follow
[Accessibility upgrades](Docs/Accessibility-Upgrades.md). See
[NOTICE.md](NOTICE.md) for the separate inherited-source license status.
