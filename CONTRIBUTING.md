# Contributing

This is the development fork for Joy-Con Unified Controller. Read the
[README](README.md), [design/acceptance contract](Docs/Unified-Controller.md) and
[attribution and authorization record](NOTICE.md) before changing controller
behavior. This fork uses the [MIT License](LICENSE); no separate contributor
license agreement is required. Submit only material you have permission to
contribute under MIT and retain applicable third-party notices.

## Report a problem

Use the bug report template. Include controller side/orientation, macOS and app
versions, selected target, Test Mode/permission state, the exact control gesture,
expected/actual behavior and the controller's Feedback message. If a keyboard
shortcut also fails physically, say so. Redact conversation text, local paths,
window titles and sensitive profile bindings from public attachments.

A sent event is not evidence that an application acted on it. Distinguish input
receipt, mapping resolution, output errors and visible page behavior. See
[SECURITY.md](SECURITY.md) for potentially sensitive reports.

## Development

Use a topic branch from the intended base; inspect local changes before editing.
Open `Package.swift` in Xcode or use SwiftPM. The repository's toolchain hint is
Swift 6.3; its manifest uses Swift 6. There are no third-party runtime packages.

```sh
swift build
swift test
```

Use focused tests during iteration. Code/release changes must complete the
[final checks](Docs/Maintenance.md#final-checks-for-code-and-release-candidates).
If OpenSpec is unavailable, report it as not run. Documentation-only changes
need reference/command/whitespace checks, not a new app installation.

The optional input logger reads physical HID events:

```sh
swift run JoyConInputLogger
swift run JoyConInputLogger --right
```

Run hardware/UI checks explicitly; do not start recording, send messages, change
live mappings or install/reset permissions as a side effect of unit tests.

## Behavioral constraints

- Keep profiles and destination validation target-local. Preserve arbitrary
  custom mappings and legacy bytes; do not migrate the original file in place.
- Preserve ordinary Capture single/double actions; preserve immediate ZL Fn and reserve its isolated triple tap for app switching; keep ZL+Capture and SL/SR disabled.
- Release held output before switching apps/inputs or entering Test Mode, and
  require neutral controls before new output.
- Keep Claude on its Code page with an unambiguous prompt. Do not substitute CLI
  shortcuts or a different app when a native control is missing.
- Test routing/geometry without embedding private conversation content.
- Report unsupported or failed native checks rather than treating mocks as proof.

## Pull requests

Explain the concrete problem, resulting behavior and affected target/input path.
List focused/full checks and separate user-reported physical results from automated
coverage. Update README, relevant OpenSpec and operating docs when behavior changes.
Keep generated builds, profiles, receipts and machine-specific state out of Git.
Preserve upstream attribution and avoid unrelated cleanup in the same change.

Do not push numeric release tags as part of an ordinary contribution: they trigger
public release publication. Signing, notarization, distribution and preservation
of applicable license/attribution notices require separate release review.
