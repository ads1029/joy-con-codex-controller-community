#!/bin/bash

set -euo pipefail

application_name="JoyConCodexControllerCommunity"
expected_bundle_id="com.ads1029.JoyConCodexControllerCommunity"
launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <release-app> [installed-app]" >&2
    exit 64
fi

source_app="$1"
installed_app="${2:-$HOME/Applications/$application_name.app}"

if [[ ! -d "$source_app/Contents" || ! -x "$source_app/Contents/MacOS/$application_name" ]]; then
    echo "Release bundle is incomplete: $source_app" >&2
    exit 66
fi

source_app="$(cd "$(dirname "$source_app")" && pwd)/$(basename "$source_app")"
installed_parent="$(dirname "$installed_app")"
mkdir -p "$installed_parent"
installed_parent="$(cd "$installed_parent" && pwd)"
installed_app="$installed_parent/$(basename "$installed_app")"

if [[ "$source_app" == "$installed_app" ]]; then
    echo "Release source and installed destination must be different paths." >&2
    exit 64
fi

bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$source_app/Contents/Info.plist")"
if [[ "$bundle_id" != "$expected_bundle_id" ]]; then
    echo "Unexpected bundle identifier: $bundle_id" >&2
    exit 65
fi

codesign --verify --deep --strict --verbose=2 "$source_app"
source_sha256="$(shasum -a 256 "$source_app/Contents/MacOS/$application_name" | awk '{print $1}')"
source_cdhash="$(codesign -d --verbose=4 "$source_app" 2>&1 | awk -F= '/^CDHash=/{print $2}')"
source_requirement="$(codesign -d -r- "$source_app" 2>&1 | tail -1)"

timestamp="$(date +%Y%m%d_%H%M%S)"
support_root="$HOME/Library/Application Support/$application_name"
backup_root="$support_root/UpgradeBackups/$timestamp-$version"
receipt_root="$support_root/AccessibilityInstallReceipts"
mkdir -p "$backup_root" "$receipt_root"
receipt="$receipt_root/$timestamp-$version.txt"
previous_bundle="$backup_root/previous-bundle"
staged_bundle="$installed_parent/.${application_name}-install-$timestamp-$$.app"
completed=0

restore_on_error() {
    local exit_status=$?
    trap - EXIT
    if [[ $completed -eq 0 && $exit_status -ne 0 && -d "$previous_bundle/Contents" ]]; then
        pkill -x "$application_name" 2>/dev/null || true
        if [[ -e "$installed_app" ]]; then
            mv "$installed_app" "$backup_root/failed-new-bundle"
        fi
        ditto "$previous_bundle" "$installed_app"
        "$launch_services" -f "$installed_app" >/dev/null 2>&1 || true
        open -n "$installed_app" >/dev/null 2>&1 || true
        echo "Installation failed; the previous installed bundle was restored." >&2
    fi
    exit "$exit_status"
}
trap restore_on_error EXIT

# Stop the old binary before changing either LaunchServices or TCC state.
if pgrep -x "$application_name" >/dev/null; then
    pkill -x "$application_name"
    for _ in {1..50}; do
        pgrep -x "$application_name" >/dev/null || break
        sleep 0.1
    done
fi

# Unregister and preserve the old installed bundle under a non-.app name so it
# cannot be selected as the permission target by LaunchServices or Spotlight.
if [[ -d "$installed_app/Contents" ]]; then
    "$launch_services" -u "$installed_app" >/dev/null 2>&1 || true
    mv "$installed_app" "$previous_bundle"
fi

# Install and verify the exact bundle that will own the new TCC request.
ditto "$source_app" "$staged_bundle"
codesign --verify --deep --strict --verbose=2 "$staged_bundle"
staged_sha256="$(shasum -a 256 "$staged_bundle/Contents/MacOS/$application_name" | awk '{print $1}')"
staged_cdhash="$(codesign -d --verbose=4 "$staged_bundle" 2>&1 | awk -F= '/^CDHash=/{print $2}')"
[[ "$staged_sha256" == "$source_sha256" ]]
[[ "$staged_cdhash" == "$source_cdhash" ]]
mv "$staged_bundle" "$installed_app"

# The release artifact is not the runtime permission target. Remove its
# registration, then register only the canonical installed path.
"$launch_services" -u "$source_app" >/dev/null 2>&1 || true
"$launch_services" -f "$installed_app"
tccutil reset Accessibility "$bundle_id"

installed_sha256="$(shasum -a 256 "$installed_app/Contents/MacOS/$application_name" | awk '{print $1}')"
installed_cdhash="$(codesign -d --verbose=4 "$installed_app" 2>&1 | awk -F= '/^CDHash=/{print $2}')"
installed_requirement="$(codesign -d -r- "$installed_app" 2>&1 | tail -1)"
[[ "$installed_sha256" == "$source_sha256" ]]
[[ "$installed_cdhash" == "$source_cdhash" ]]

cat > "$receipt" <<EOF
timestamp=$timestamp
version=$version
bundle_id=$bundle_id
source_app=$source_app
installed_app=$installed_app
binary_sha256=$installed_sha256
cdhash=$installed_cdhash
designated_requirement=$installed_requirement
tcc_service=Accessibility
tcc_reset=completed_after_new_bundle_install
launch_argument=--request-accessibility
EOF

# This exact new process performs AXIsProcessTrustedWithOptions(prompt: true).
if ! open -n "$installed_app" --args --request-accessibility; then
    "$installed_app/Contents/MacOS/$application_name" --request-accessibility \
        >> "$backup_root/launch.log" 2>&1 &
fi
for _ in {1..50}; do
    pgrep -x "$application_name" >/dev/null && break
    sleep 0.1
done
pid="$(pgrep -x "$application_name" | head -1)"
running_command="$(ps -p "$pid" -o command=)"
case "$running_command" in
    "$installed_app/Contents/MacOS/$application_name"*) ;;
    *)
        echo "Unexpected running executable: $running_command" >&2
        exit 70
        ;;
esac

sleep 0.5
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

{
    echo "pid=$pid"
    echo "running_executable=$running_command"
    echo "permission_target_cdhash=$installed_cdhash"
} >> "$receipt"

completed=1
trap - EXIT

echo "Installed $application_name $version"
echo "Installed path: $installed_app"
echo "Permission target CDHash: $installed_cdhash"
echo "Receipt: $receipt"
echo "Enable the single $application_name entry now shown in Accessibility, then use Refresh Permission in the app."
