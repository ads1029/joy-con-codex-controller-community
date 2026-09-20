# Accessibility permission after local app upgrades

## Why an upgrade needs a fresh permission grant

Local release bundles are currently ad-hoc signed. Their designated requirement
is the build's exact code-directory hash, for example:

```text
# designated => cdhash H"<CURRENT_CDHASH>"
Signature=adhoc
TeamIdentifier=not set
```

Rebuilding the executable changes that `CDHash`. macOS TCC therefore treats the
new bundle as a new Accessibility client even when its bundle identifier and
installed path are unchanged. An old enabled row can still refer to the previous
hash and does not establish trust for the new process.

The permanent distribution fix is signing every release with the same Apple
Development or Developer ID identity and a stable designated requirement. Until
that signing identity is available, every ad-hoc upgrade must use the refresh
procedure below.

## Required invariant

The application that calls
`AXIsProcessTrustedWithOptions(prompt: true)` must be the exact verified bundle
at the canonical installed path:

```text
~/Applications/JoyConCodexControllerCommunity.app
```

Do not launch the bundle under `dist/`, a backup bundle, or an older build and
then grant its prompt. Those paths can send the permission decision to a stale
hash.

## Standard upgrade command

Build the release, then install it with the dedicated script:

```bash
bash Scripts/build-release.sh <VERSION>
bash Scripts/install-local-release.sh \
  "dist/JoyConCodexControllerCommunity.app"
```

The installer performs this ordered transaction:

1. Verify the release signature, bundle identifier, binary SHA-256, `CDHash`,
   and designated requirement.
2. Stop the currently running controller.
3. Unregister the old canonical bundle from LaunchServices.
4. Preserve it under `Application Support` using a non-`.app` backup name.
5. Copy and re-verify the new bundle at the canonical installed path.
6. Unregister the `dist/` source so it is not selected as the permission target.
7. Register only the canonical new bundle with LaunchServices. This must happen
   before the bundle-ID-based TCC reset, or `tccutil` returns `-10814`.
8. Run `tccutil reset Accessibility <BUNDLE_ID>` **after** the new bundle is in
   place, registered, and the old process is stopped.
9. Launch that exact bundle with `--request-accessibility`; the new process then
   calls `AXIsProcessTrustedWithOptions(prompt: true)`.
10. Open System Settings at **Privacy & Security → Accessibility**.
11. Write a receipt containing the installed path, SHA-256, `CDHash`, designated
    requirement, PID, and running executable.

The script preserves the previous bundle and restores it automatically when an
installation step fails before completion.

## Grant and verify

When System Settings opens:

1. Find the single `Joy-Con Codex Controller Community` row.
2. Enable it. If it is already enabled immediately after a reset, toggle it off
   once and back on.
3. Return to the controller and choose **Refresh Permission**.
4. Confirm the orange `Accessibility permission required` status changes to the
   live-output state.
5. Test one harmless mapped action before starting normal use.

Inspect the receipt created by the installer:

```bash
ls -t "$HOME/Library/Application Support/JoyConCodexControllerCommunity/AccessibilityInstallReceipts" \
  | head -1
```

The receipt's `running_executable` must point to the canonical installed path,
and its `permission_target_cdhash` must match:

```bash
codesign -d --verbose=4 \
    "$HOME/Applications/JoyConCodexControllerCommunity.app" 2>&1 \
  | grep '^CDHash='
```

## Recovery when the orange status persists

Rerun the installer against the already-built release bundle. It is intentionally
safe to use as a permission refresh because it keeps a backup and repeats the
full ordering:

```bash
bash Scripts/install-local-release.sh \
  "dist/JoyConCodexControllerCommunity.app"
```

Then enable the newly prompted row and use **Refresh Permission**. Avoid opening
or granting a copy from `dist/`, `.codex/`, an archive extraction directory, or
`UpgradeBackups/`.

## Release checklist

- [ ] Release bundle passes `codesign --verify --deep --strict`.
- [ ] Installer reports identical source and installed SHA-256 / `CDHash`.
- [ ] Old process is stopped before the TCC reset.
- [ ] TCC reset occurs after the new bundle reaches the canonical path.
- [ ] New canonical process launches with `--request-accessibility`.
- [ ] Receipt PID and executable path match the canonical bundle.
- [ ] System Settings shows one current controller row.
- [ ] App reports live Accessibility trust after **Refresh Permission**.
- [ ] Rollback bundle and user mapping profile remain preserved.
