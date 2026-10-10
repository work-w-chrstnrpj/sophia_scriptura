#!/bin/bash
# Personal, in-place installation using the project's existing signing settings.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: scripts/install-ipad.sh [options]

Build signed Debug Sophia, install over the existing app, and launch it.
Run from any directory. Connect and unlock the iPad before running.

  --device NAME_OR_ID  Target device (default: iPad ni Paj)
  --list-devices       List known devices and exit
  --dry-run            Print commands without building or contacting the iPad
  --no-launch          Install without opening the app
  -h, --help           Show this help

First-time setup: sign in to Xcode, select your existing Personal Team,
pair the iPad, enable Developer Mode, and trust your developer profile.
DEVELOPER_DIR may select a different full Xcode installation.
EOF
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
device='iPad ni Paj'
dry_run=false
launch=true
list_devices=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --device)
            [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || fail '--device requires a name or identifier.'
            device="$2"; shift 2 ;;
        --dry-run) dry_run=true; shift ;;
        --no-launch) launch=false; shift ;;
        --list-devices) list_devices=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1 (use --help)" ;;
    esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$root/application/SophiaScriptura/SophiaScriptura.xcodeproj"
derived="$root/build/ipad-install/DerivedData"
app="$derived/Build/Products/Debug-iphoneos/SophiaScriptura.app"
bundle_id='com.personal.SophiaScriptura'
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

print_command() { printf '  '; printf '%q ' "$@"; printf '\n'; }
if $list_devices; then
    if $dry_run; then
        print_command xcrun devicectl list devices
    else
        xcrun devicectl list devices
    fi
    exit 0
fi

[[ -d "$project" ]] || fail "Project missing: $project"
if [[ "$device" =~ ^[0-9A-Fa-f-]{20,}$ ]]; then
    build_destination="id=$device"
else
    build_destination='generic/platform=iOS'
fi
build_command=(xcrun xcodebuild -project "$project" -scheme SophiaScriptura
    -configuration Debug -destination "$build_destination"
    -derivedDataPath "$derived" -allowProvisioningUpdates build)
install_command=(xcrun devicectl device install app --device "$device" "$app")
# A string-only environment replaces inherited DEVICECTL_CHILD_* test variables.
# Current devicectl rejects an empty JSON object.
launch_command=(xcrun devicectl device process launch --device "$device"
    --terminate-existing --environment-variables '{"SOPHIA_LAUNCH":"user"}' "$bundle_id")

printf 'Target: %s\nXcode: %s\n' "$device" "$DEVELOPER_DIR"
if $dry_run; then
    print_command xcrun devicectl device info details --device "$device"
    print_command "${build_command[@]}"
    print_command codesign --verify --deep --strict "$app"
    print_command /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist"
    printf '  Require bundle identifier: %s\n' "$bundle_id"
    print_command "${install_command[@]}"
    if $launch; then print_command "${launch_command[@]}"; fi
    exit 0
fi

[[ -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]] || fail 'Set DEVELOPER_DIR to a full Xcode installation.'
logs="$root/build/ipad-install/logs/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$logs"
printf 'Logs: %s\n' "$logs"
run_step() {
    local step="$1"
    shift
    printf '\n%s…\n' "$step"
    "$@" 2>&1 | tee "$logs/$step.log"
}

if ! run_step device xcrun devicectl device info details --device "$device"; then
    fail 'Check the cable, unlock/trust the iPad, or use --list-devices and --device.'
fi
if ! run_step build "${build_command[@]}"; then
    fail 'Build failed; nothing installed. Check build.log. For signing errors, open Xcode → Settings → Accounts and the target’s Signing & Capabilities.'
fi
[[ -d "$app" ]] || fail "Built app missing: $app"
if ! run_step signature codesign --verify --deep --strict "$app"; then
    fail 'Signature verification failed; nothing installed. Check signature.log.'
fi
actual_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist")
[[ "$actual_id" == "$bundle_id" ]] || fail "Unexpected bundle identifier: $actual_id. Nothing installed. Keep the existing app identity."
if ! run_step install "${install_command[@]}"; then
    fail 'Installation failed. Check install.log, device connection, signing, and Developer Mode. Do not delete the existing app.'
fi
printf '\nSophia installed in place.\n'
if $launch; then
    if ! run_step launch "${launch_command[@]}"; then
        fail 'Installation succeeded, but launch failed. Unlock the iPad. If asked, trust your profile in Settings → General → VPN & Device Management, then open Sophia manually.'
    fi
    printf '\nSophia launched successfully. You can disconnect the iPad.\n'
fi
