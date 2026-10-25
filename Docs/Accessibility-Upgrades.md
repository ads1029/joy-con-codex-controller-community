# Accessibility upgrades and recovery

Applies to **Joy-Con Unified Controller 0.2.11**. The bundle identifier is
`com.ads1029.JoyConUnifiedController`. Do not reset the original controller's
permissions or grant a backup/dist copy by mistake.

## Canonical installation

Use one installed path for both runtime and permission requests. The local
accepted installation uses:

```text
/Applications/JoyConUnifiedController.app
```

The installer defaults to `~/Applications/JoyConUnifiedController.app` when its
second argument is omitted. That is a supported alternative, but upgrades must
keep using the same destination. Do not run both copies.

## Why permission can break after a rebuild

Current packages are ad-hoc signed. A changed executable can change the code
hash used by macOS Accessibility/TCC. An enabled row for the previous binary
does not prove the new process is trusted. Rebuilding an unchanged binary need
not change its hash. Stable signing with an appropriate Apple identity is a
future distribution task; these builds are not notarized.

## Upgrade

Build first, then explicitly install to your chosen canonical path:

```sh
bash Scripts/build-release.sh 0.2.11
bash Scripts/install-local-release.sh \
  "dist/JoyConUnifiedController.app" \
  "/Applications/JoyConUnifiedController.app"
```

The installer:

1. Checks bundle identity, signature and executable hashes; rejects replacement
   of a different application identity.
2. Stops the unified process and preserves the previous bundle under a non-app
   backup name.
3. Stages, verifies and installs the replacement.
4. Unregisters the build source and registers the canonical installed path.
5. Resets only `Accessibility` for `com.ads1029.JoyConUnifiedController`.
6. Starts that exact bundle with `--request-accessibility`, opens System Settings
   and writes an installation receipt.

A failure after preserving the previous bundle triggers a rollback attempt;
review the reported result. Installation does not edit the legacy profile or
supply the user's macOS permission decision.

## Grant and verify

1. In **System Settings → Privacy & Security → Accessibility**, enable the
   JoyConUnifiedController entry for the installed app. If a stale enabled row
   persists after upgrade, turn it off and on again.
2. Return to the controller and choose **Request / Refresh**.
3. Confirm **Accessibility permission granted**.
4. Keep Test Mode on while checking inputs. Then disable it, focus the selected
   target, release all controls and test scrolling. For Claude use its Code page.

A successful permission status is separate from correct app/prompt routing and
physical controller acceptance. Input Monitoring, if requested by macOS for the
build, is also a separate system permission. Claude manages its own microphone
permission; the controller does not capture audio.

## Receipts, backups and verification

```text
~/Library/Application Support/JoyConUnifiedController/AccessibilityInstallReceipts/
~/Library/Application Support/JoyConUnifiedController/UpgradeBackups/
```

The installer receipt records `installed_app`, version, binary SHA-256,
`cdhash`, designated requirement, PID and `running_executable`. Compare its
canonical path and hash with the installed bundle:

```sh
codesign --verify --deep --strict "/Applications/JoyConUnifiedController.app"
codesign -d --verbose=4 "/Applications/JoyConUnifiedController.app" 2>&1
shasum -a 256 \
  "/Applications/JoyConUnifiedController.app/Contents/MacOS/JoyConUnifiedController"
```

Use your actual installed path if different. Receipts can contain local paths
and process details; redact them before posting publicly.

## If output remains blocked

- Quit duplicate controller copies and other known controller utilities.
- Confirm the running app uses the same path as the receipt and permission grant.
- Retry **Request / Refresh**, then the selected target's Focus action.
- If permission remains stale, rerun the installer against the built release
  using the same explicit destination, and enable the renewed row.
- Read the controller's **Feedback** text. A missing Claude Code tree or ambiguous
  prompt is a target-readiness issue, not proof of a TCC failure.
- For Codex/ChatGPT scrolling, `mode=ax` identifies semantic routing and
  `mode=legacy-window` identifies the compatibility point. Neither proves that
  the page moved; test a long conversation physically.

Avoid granting copies in `dist/`, archive extraction directories or
`UpgradeBackups/`. Re-record the desktop layout if its selected window was closed
or destinations changed. Do not repeatedly reset unrelated applications' grants.
