#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
umask 077
key_temp=''
finish() {
    result=$?
    if [ -n "$key_temp" ] && [ -d "$key_temp" ]; then rm -rf "$key_temp"; fi
    if [ "$result" -ne 0 ]; then printf '\nSetup stopped. Copy the error above into ChatGPT.\n'; fi
    printf '\nPress Return to close.\n'
    read -r _ || true
}
trap finish EXIT
[ "$(uname -s)" = Darwin ] || { printf 'Run this setup on your Mac.\n'; exit 1; }
if ! xcrun --find swiftc >/dev/null 2>&1; then
    xcode-select --install || true
    printf 'Finish installing Apple Command Line Tools, then run this again.\n'
    exit 1
fi
if ! command -v gh >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
        printf 'Installing GitHub CLI with Homebrew…\n'
        brew install gh
    else
        printf 'Install GitHub CLI from https://cli.github.com, then run this again.\n'
        open https://cli.github.com
        exit 1
    fi
fi
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow
fi
login="$(gh api user --jq .login)"
if [ "$login" != NigelTatem ]; then
    printf 'GitHub CLI is signed in as %s. Switch to NigelTatem before continuing.\n' "$login"
    exit 1
fi
repository=NigelTatem/ambience
repo_exists=false
if gh repo view "$repository" >/dev/null 2>&1; then
    repo_exists=true
    if [ "$(gh repo view "$repository" --json isPrivate --jq .isPrivate)" = true ]; then
        printf 'The existing repository is private. This free public distribution setup will not change its visibility.\n'
        exit 1
    fi
    remote_default="$(gh repo view "$repository" --json defaultBranchRef --jq '.defaultBranchRef.name // ""')"
    if [ -n "$remote_default" ] && [ ! -d .git ]; then
        printf 'The repository already has commits. Stop here and ask ChatGPT to update that repository instead of uploading a second copy.\n'
        exit 1
    fi
fi
if [ -d .git ]; then
    origin="$(git remote get-url origin 2>/dev/null || true)"
    if [ -n "$origin" ] && [ "$origin" != "https://github.com/$repository.git" ]; then
        printf 'This folder has a different Git remote. Nothing was changed.\n'
        exit 1
    fi
elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'Extract this project outside another Git repository, then run setup again.\n'
    exit 1
fi

sparkle_dir="$(bash scripts/fetch-sparkle.sh)"
account=com.nigeltatem.ambience
mkdir -p Config
if [ -f Config/update-public-key.txt ]; then
    # Never silently replace a deployed public key with a new one.
    public_key="$("$sparkle_dir/bin/generate_keys" --account "$account" -p)"
    expected="$(tr -d '\r\n' < Config/update-public-key.txt)"
    [ "$public_key" = "$expected" ] || { printf 'Your Keychain signing key does not match this project. Restore the original key before releasing updates.\n'; exit 1; }
else
    "$sparkle_dir/bin/generate_keys" --account "$account"
    "$sparkle_dir/bin/generate_keys" --account "$account" -p > Config/update-public-key.txt
fi
printf '\nBuilding locally before publishing source…\n'
bash scripts/build-app.sh

if [ "$repo_exists" = false ]; then
    gh repo create "$repository" --public --description 'Free, customizable video wallpapers for macOS, with sound, framing controls, and signed updates.'
fi
key_temp="$(mktemp -d "${TMPDIR:-/tmp}/ambience-key.XXXXXX")"
"$sparkle_dir/bin/generate_keys" --account "$account" -x "$key_temp/private-key"
gh secret set SPARKLE_PRIVATE_KEY --repo "$repository" < "$key_temp/private-key"
rm -f "$key_temp/private-key"
rmdir "$key_temp"
key_temp=''

if [ ! -d .git ]; then git init -b main; fi
if ! git remote get-url origin >/dev/null 2>&1; then git remote add origin "https://github.com/$repository.git"; fi
branch="$(git branch --show-current)"
[ "$branch" = main ] || { printf 'Switch this project to the main branch before continuing.\n'; exit 1; }
git add Sources Tests scripts .github Config Resources Info.plist .gitignore README.md START-HERE.md PUBLISHING.md CATALOG.md RELEASE-NOTES.md Build-and-Run.command Setup-Publishing.command
if ! git diff --cached --quiet; then
    user_id="$(gh api user --jq .id)"
    git -c user.name=NigelTatem -c user.email="$user_id+NigelTatem@users.noreply.github.com" \
        commit -m 'Prepare Ambience public distribution and signed updates'
fi
git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push -u origin main
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
if ! git rev-parse "v$version" >/dev/null 2>&1; then git tag "v$version"; fi
git -c credential.helper= -c 'credential.helper=!gh auth git-credential' push origin "v$version"
printf '\nSource uploaded. GitHub is preparing a DRAFT release.\n'
printf 'Test the DMG before publishing the draft as the Latest release.\n'
open "https://github.com/$repository/actions"
printf '\nInstalling this updater-enabled build locally…\n'
# This final installer retains your existing collection and asks you to quit a running copy.
bash Build-and-Run.command --use-built
