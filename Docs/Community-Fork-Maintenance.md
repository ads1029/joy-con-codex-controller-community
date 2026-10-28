# Community fork identity and upstream policy

## Source and scope

This repository is an independent community-maintained fork of
[Jinjiang/joy-con-codex-micro](https://github.com/Jinjiang/joy-con-codex-micro),
based on its 0.1.12 baseline. Repository:
[`ads1029/joy-con-codex-controller-community`](https://github.com/ads1029/joy-con-codex-controller-community).
The app is now **Joy-Con Unified Controller**; the repository keeps its existing
name and upstream history.

Basic single-Joy-Con support, portrait/layered mapping and the original controller
workflow are inherited. Fork work includes battery/HID improvements, repeated
scrolling and double-tap handling, unified target/profile routing, Claude input
selection, desktop layout/HUD and desktop compatibility fixes. Berrry Joyful was
reviewed as prior art; no second Berrry process or copied speech engine is used.

## Current identities

| Item | Unified candidate |
| --- | --- |
| Version | 0.3.0, first community release (ad-hoc signed, not notarized) |
| App/display name | `JoyConUnifiedController.app` / Joy-Con Unified Controller |
| Executable product | `JoyConUnifiedController` |
| Bundle/defaults identity | `com.ads1029.JoyConUnifiedController` |
| Profile/support directory | `~/Library/Application Support/JoyConUnifiedController/` |
| Swift package | `joy-con-codex-controller-community` |
| Source targets | `JoyConCodexController`, `JoyConCodexCore` (retained names) |

The earlier Community identity
`com.ads1029.JoyConCodexControllerCommunity` and the original controller identity
are historical applications, not current installation targets. Unified profiles
and preferences are isolated; only the original mapping profile is read as an
optional baseline. Preserve these identities together across packaging, scripts,
metadata and documentation when changing them.

## Attribution and license status

This fork is distributed under [MIT](../LICENSE). On 2026-10-28, Minjie Huang
confirmed direct permission from the upstream maintainer to add MIT to this
fork; [NOTICE.md](../NOTICE.md) records that authorization basis. Keep upstream
links, author attribution, Git history and the MIT copyright/permission notices.
Check attribution and licensing separately for any newly imported code or assets.
Binary signing, notarization and release acceptance still require their own checks.

## Branches and upstream sync

- `origin` is the Community fork and the normal push destination.
- `upstream` identifies the original repository and is used for comparison.
- Current unified development uses `codex/unified-desktop-controller`; keep
  development changes on a topic branch until reviewed.
- Do not force-reset a branch over fork-owned work or silently combine concurrent
  changes. Review upstream syncs as their own merge/rebase operation.

For a fresh clone, add the upstream remote if needed and disable its push URL:

```sh
git remote add upstream https://github.com/Jinjiang/joy-con-codex-micro.git
git remote set-url --push upstream no_push
```

Local remote configuration is not stored in Git. Inspect existing remotes before
running these commands; omit `remote add` when upstream is already configured.

## Contribution and release

Describe whether a change is inherited, an enhancement, or new fork behavior.
Follow [CONTRIBUTING.md](../CONTRIBUTING.md) and the
[maintenance/release checks](Maintenance.md). Unit tests do not establish physical
Joy-Con output, accessibility trust, speech behavior or desktop restoration.

A numeric tag triggers the publishing workflow. Keep branch pushes separate
from release authorization; no candidate tag/public release is claimed merely
because local builds pass. Do not detach the GitHub fork or change repository
ownership as part of routine maintenance. Such changes need a separate decision.
