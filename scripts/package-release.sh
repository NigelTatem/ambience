#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
: "${SPARKLE_PRIVATE_KEY:?The SPARKLE_PRIVATE_KEY Actions secret is required.}"
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
if [ "${GITHUB_REF_TYPE:-}" = tag ] && [ "${GITHUB_REF_NAME:-}" != "v$version" ]; then
    printf 'Release tag must match Info.plist version v%s.\n' "$version" >&2
    exit 1
fi
bash scripts/build-app.sh --release
mkdir -p dist
archive="$PWD/dist/Ambience-$version.zip"
ditto -c -k --sequesterRsrc --keepParent build/Ambience.app "$archive"
sparkle_dir="$(bash scripts/fetch-sparkle.sh)"
# Never place private keys in process arguments or logs. Sparkle reads the key from standard input.
signature="$(printf '%s' "$SPARKLE_PRIVATE_KEY" | "$sparkle_dir/bin/sign_update" --ed-key-file - -p "$archive")"
xcrun swiftc scripts/VerifyUpdate.swift -o build/verify-update
build/verify-update Config/update-public-key.txt "$signature" "$archive"
python3 scripts/make-appcast.py build/Ambience.app/Contents/Info.plist "$archive" "$signature" dist/appcast.xml
# The DMG is for first installation; automatic updates use the signed app-only ZIP above.
dmg_stage="$(mktemp -d "$PWD/build/dmg.XXXXXX")"
ditto build/Ambience.app "$dmg_stage/Ambience.app"
ln -s /Applications "$dmg_stage/Applications"
hdiutil create -quiet -ov -volname Ambience -srcfolder "$dmg_stage" -format UDZO "dist/Ambience-$version.dmg"
shasum -a 256 "dist/Ambience-$version.zip" "dist/Ambience-$version.dmg" > dist/SHA256SUMS.txt
printf 'Packaged Ambience %s for Apple Silicon and Intel.\n' "$version"
