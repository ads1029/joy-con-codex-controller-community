# Maintenance and release policy

Updated 2026-10-25. The original **0.1.12** remains the historical maintenance
baseline. Active development is reopened for **0.2.11**, the unified Codex /
Claude Desktop Code candidate. It is installed separately; it has not been
promoted to a stable public release.

## Scope

Maintain controller input, mapping/persistence, target isolation, prompt
selection, desktop compatibility, accessibility, packaging and documentation.
New integrations, unrelated controller families and network services need a
separate scope decision. Preserve upstream attribution, legacy profiles and the
original installed controller.

See [the acceptance contract](Unified-Controller.md) for current features and
[the fork policy](Community-Fork-Maintenance.md) for attribution/release limits.

## Change procedure

1. Describe the observable defect or behavior, app/macOS versions and input path.
2. Keep the change narrow. Add or extend a focused regression for a reproducible
   bug or critical new behavior where automation can establish it.
3. Update relevant README, OpenSpec and operating instructions.
4. Run affected checks while iterating. For code/release changes, complete the
   final checks below; document unavailable tools explicitly.
5. Report physical/native results independently of unit tests and builds.

Documentation-only changes need link, example, metadata and whitespace checks;
they do not require rebuilding, reinstalling or resetting permissions.

## Final checks for code and release candidates

```sh
swift test
# When the CLI is installed:
openspec validate --all --strict
bash Scripts/build-release.sh 0.2.11
codesign --verify --deep --strict dist/JoyConUnifiedController.app
(cd dist && shasum -a 256 -c JoyConUnifiedController-0.2.11-macOS-arm64.zip.sha256)
git diff --check
```

Replace the version/architecture for a future candidate. Verify installed hashes
against the built bundle when testing an upgrade, and keep a recoverable backup.
The current 0.2.11 record is **114 tests in 19 suites passed**, release/signature/
checksum checks passed; OpenSpec strict validation was not run because its CLI
was unavailable. This is a recorded result, not a guarantee for later commits.

## Physical smoke checks

| Area | Check |
| --- | --- |
| Input | Intended device, portrait/sideways orientation, L/ZL, stick click and disabled SL/SR |
| Suppression | Test Mode emits no mappings or automatic window moves |
| Switching | ZL+Capture changes target; held recording releases; neutral controls are required |
| Ordinary actions | Capture single/double, repeat boundaries, dictation start/stop, scrolling and bottom |
| Claude panes | ZL+fresh left/right selects the correct input; recording/scrolling follow it |
| Codex compatibility | Sidebar chat navigation and panel shortcuts match the installed app |
| Connection | Reconnect and launch-with-connected restore the selected desktop/windows and show one HUD |
| Failures | Closed window, deleted desktop, changed display, missing app or denied permission produce visible errors |
| Lifecycle | Background input, battery reporting, main-window close and clean quit |

Right-controller and complex multi-pane behavior need their own acceptance.
Do not carry an older app version's native results forward without qualification.

## Publishing

Numeric `X.Y.Z` tag pushes trigger `.github/workflows/release.yml`, which builds
and publishes an ad-hoc-signed Apple-silicon GitHub Release. A normal branch push
does not publish a release. Do not create a tag merely to save a candidate.

Before publishing, resolve the recorded attribution/license gate, review release
notes and remaining hardware checks, align app metadata/build version, verify
artifacts, and complete signing/notarization decisions for the intended audience.
See [NOTICE.md](../NOTICE.md). This documentation update does not resolve that
gate or claim a public release.
