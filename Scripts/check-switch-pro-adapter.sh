#!/bin/bash
set -euo pipefail

case "${1:-}" in
    ''|--build-only|--snapshot) ;;
    *) echo "Usage: $0 [--build-only|--snapshot]" >&2; exit 64 ;;
esac
if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [--build-only|--snapshot]" >&2
    exit 64
fi
if [[ "$(uname -s)" != Darwin ]]; then
    echo "Switch Pro adapter probe requires macOS." >&2
    exit 2
fi

root="$(cd "$(dirname "$0")/.." && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
work="$(cd "$work" && pwd -P)"
cd "$root"

swift build --scratch-path "$work/build" --target JoyConCodexCore
bin="$(swift build --scratch-path "$work/build" --show-bin-path)"
sources="$root/Sources/JoyConCodexController"
swiftc -swift-version 6 -parse-as-library -I "$bin/Modules" \
    -framework GameController -framework CoreHaptics -framework IOKit \
    "$sources/GameControllerAdapter.swift" "$sources/LeftJoyConHIDAdapter.swift" \
    "$sources/RightJoyConHIDAdapter.swift" "$root/Tools/SwitchProAdapterProbe.swift" \
    "$bin"/JoyConCodexCore.build/*.swift.o -o "$work/SwitchProAdapterProbe"

if [[ "${1:-}" == --build-only ]]; then
    echo "Switch Pro adapter probe built (hardware check not run)."
    exit 0
fi
"$work/SwitchProAdapterProbe" "$@"
