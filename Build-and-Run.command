#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"

on_exit() {
    result=$?
    if [ "$result" -ne 0 ]; then
        printf '\nBuild stopped (exit %s). Copy the error above into ChatGPT.\n' "$result"
    fi
    printf '\nPress Return to close.\n'
    read -r _ || true
}
trap on_exit EXIT

if [ "$(uname -s)" != "Darwin" ]; then
    printf 'Run this script on your Mac, not on Linux or Windows.\n'
    exit 1
fi
os_major="$(sw_vers -productVersion | cut -d. -f1)"
if [ "$os_major" -lt 13 ]; then
    printf 'Ambience needs macOS Ventura 13 or later.\n'
    exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
    printf 'Apple Command Line Tools are needed once. Accept the installation prompt, then run this file again after installation completes.\n'
    xcode-select --install || true
    exit 1
fi

if [ "${1:-}" != --use-built ]; then bash scripts/build-app.sh; fi
bundle="$PWD/build/Ambience.app"
[ -x "$bundle/Contents/MacOS/Ambience" ] || { printf 'No built app found. Run the normal build first.\n'; exit 1; }

destination="$HOME/Applications/Ambience.app"
mkdir -p "$HOME/Applications"
if pgrep -x Ambience >/dev/null 2>&1; then
    printf '\nAmbience is already running. Quit it from the leaf menu, then press Return to install this build.\n'
    read -r _
    if pgrep -x Ambience >/dev/null 2>&1; then
        printf 'Ambience is still running. Quit it and run this script again.\n'
        exit 1
    fi
fi
# Keep the previous app until the new one is fully built and signed.
backup=''
if [ -e "$destination" ]; then
    backup="$HOME/Applications/Ambience-backup-$(date +%Y%m%d-%H%M%S).app"
    mv "$destination" "$backup"
fi
if ! mv "$bundle" "$destination"; then
    if [ -n "$backup" ]; then mv "$backup" "$destination"; fi
    printf 'Could not install the new app.\n'
    exit 1
fi
open "$destination"
printf '\nInstalled: %s\n' "$destination"
printf 'Use Add Videos to import your MP4s. The leaf in your menu bar opens the controls.\n'
printf 'Enable Launch at login in the app if you want it to return after signing in.\n'
