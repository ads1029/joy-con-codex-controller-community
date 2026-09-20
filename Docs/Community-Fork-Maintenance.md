# Community fork maintenance plan

## Purpose

This repository is a community-maintained fork of
[`Jinjiang/joy-con-codex-micro`](https://github.com/Jinjiang/joy-con-codex-micro).
The fork may evolve independently when upstream review or feature development
is not available, while preserving clear attribution and a usable path for
upstream comparison.

This document records the maintenance plan and the current implementation
state. It does not grant any license to inherited code.

## Current baseline

- Fork remote: `origin`
- Upstream remote: `upstream`
- Stable baseline: `0.1.12`
- Repository: `ads1029/joy-con-codex-controller-community`
- Supported platform: Apple silicon Mac running macOS 14 or newer
- Fork relationship: keep the GitHub fork relationship for now
- Basic single-Joy-Con support: inherited from upstream; it is not claimed as a
  feature introduced by this fork

The fork's additional work should be described as enhancements to the existing
single-Joy-Con workflow. Examples already represented by the current fork
history include battery reporting, left Joy-Con raw-HID supplementation,
scrolling, double-tap and repeat behavior, Codex focus behavior, and local
installation/accessibility guidance.

## Required legal and attribution gate

The upstream repository currently has no detected `LICENSE` file. Before
publicly redistributing a modified build or presenting the inherited source as
an independently licensed project:

1. Ask the upstream maintainer for explicit permission or a clear license.
2. Keep the upstream URL, author attribution, and inherited history visible.
3. Do not add an MIT, Apache, or other license to the entire repository unless
   the right to license the inherited code has been established.
4. Treat the fork as a development/community fork until this gate is resolved.

Licensing only code authored in this fork must not be presented as licensing
the upstream code.

## Change sequence and status

Do these as separate, reviewable steps rather than one large change.

### 1. Repository metadata — complete

- Repository renamed to `joy-con-codex-controller-community`.
- GitHub About description, homepage, and topics identify this as a community
  fork.
- README title, attribution, project status, feature list, and upstream link
  are updated.

Renaming the GitHub repository does not rename the macOS application. Update
the local `origin` URL after the rename even though GitHub normally redirects
the old repository URL.

### 2. Application identity — complete for the current baseline

When this fork is intended to coexist with the upstream app, use a distinct
identity:

- `CFBundleDisplayName` is `Joy-Con Codex Controller Community`.
- `CFBundleIdentifier` is `com.ads1029.JoyConCodexControllerCommunity`.
- The Swift package name, app metadata, release script, installer expectation,
  README, and Accessibility guidance identify the community fork.
- The binary target remains `JoyConCodexController` for source compatibility;
  the next published fork release will be versioned independently after the
  `0.1.12` baseline is ready.

The bundle identifier is changed before side-by-side installation so
Accessibility/TCC registration and local upgrades do not target the upstream
application identity. The existing profile directory and UserDefaults keys
remain stable for migration compatibility with 0.1.12; this is intentional and
should be revisited before claiming fully isolated side-by-side profiles.

### 3. Git and branch discipline — local guard complete

- `origin` is the fork and the only normal push destination.
- `upstream` is read-only and points to the original repository.
- `main` contains the fork's stable, releasable state.
- New work uses `feature/*` or `fix/*` branches.
- Never force-reset `main` to `upstream/main` when fork-owned commits exist.
- Sync upstream deliberately with `git fetch upstream` followed by a reviewed
  merge or rebase, then push only to `origin`.

The local `upstream` push URL is disabled as a guard against accidental pushes.
Recommended local guard for fresh clones:

```sh
git remote set-url --push upstream no_push
```

### 4. Feature work — policy active

Every feature should state whether it is:

- inherited from upstream;
- an enhancement to an existing controller path; or
- genuinely new fork functionality.

Each feature should include focused tests where possible, documentation of
user-visible behavior, and a manual Joy-Con check when hardware behavior is
involved.

### 5. Release procedure — ready, not yet publicly promoted

Before publishing a fork release:

1. Run `swift test`.
2. Run `openspec validate --all --strict` when available.
3. Build with `bash Scripts/build-release.sh <version>`.
4. Verify the signature, archive checksum, and release notes.
5. Perform a real-controller smoke test covering connection, mappings,
   Test Mode, Accessibility, background input, battery status, and clean quit.
6. Publish a tagged GitHub Release that identifies the upstream baseline and
   fork-specific changes.

## GitHub features that may be changed independently

The fork may have its own branches, issues, pull requests, projects, Actions,
labels, wiki, releases, and repository description. Changes there do not alter
the upstream repository. Keep project/task descriptions aligned with the
README and this plan.

## Fork detachment policy

Do not detach the fork yet. Detachment is permanent and can discard GitHub
metadata such as issues, pull requests, wiki content, stars, watchers, and
comments. Consider it only after the legal gate is resolved and the fork has a
stable independent identity and release history.

## Current phase

Repository metadata, README attribution, application identity, and the local
upstream push guard are now in place. The legal/attribution gate remains open:
no independent public redistribution license has been established for the
inherited source, so no standalone public fork release or fork detachment is
claimed here. Future feature or release changes must be made one at a time and
recorded against this baseline.
