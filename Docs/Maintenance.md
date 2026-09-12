# Maintenance policy

## Status

- Lifecycle: **maintenance**
- Effective date: 2026-09-13
- Stable feature baseline: **0.1.12**
- Source of truth: this Git repository and its tagged release source
- Supported platform: Apple silicon Mac running macOS 14 or newer

The planned first-release scope is complete. Routine work now keeps the existing
controller workflow reliable instead of expanding the product surface.

## Accepted maintenance work

- Reproducible controller input, mapping, persistence, or lifecycle defects
- Compatibility repairs required by a supported macOS or Swift release
- Security, privacy, signing, notarization, and packaging corrections
- Small mapping adjustments justified by observed day-to-day controller use
- Documentation corrections that keep behavior and operating procedures aligned

New integrations, speculative shortcuts, unrelated controller families, network
services, and rich Codex status features require an explicit decision to reopen
active development.

## Required change procedure

1. Record the observed problem and affected hardware or macOS version.
2. Add or update a focused regression test where automation is possible.
3. Keep the README, OpenSpec, and operational documentation synchronized.
4. Run `swift test`.
5. Run `openspec validate --all --strict` when `openspec` is available.
6. Build the candidate with `bash Scripts/build-release.sh <version>`.
7. Verify the app signature, archive checksum, and a real-controller smoke test
   before promoting a new stable version.

## Stable-baseline acceptance

Version 0.1.12 is accepted as the maintenance baseline when all automated Swift
tests pass, the release bundle builds, `codesign --verify --deep --strict` passes,
and the generated archive checksum matches. Hardware-specific behavior remains a
manual smoke check because CI does not have an attached Joy-Con.

## Manual smoke checklist

- Pair and connect the intended left or right Joy-Con.
- Confirm portrait/sideways directions and SL/SR/L/ZL inputs.
- Confirm L3, including its Default and Fn mappings.
- Confirm Test Mode suppresses output.
- Confirm live shortcuts work after Accessibility permission is granted.
- Confirm background input, menu-bar status, battery status, and clean quit.

## Reopening criteria

Move the project back to active development only when a named release has an
approved feature goal, acceptance tests, and an owner. A backlog idea by itself
does not change the maintenance status.
