#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
[ "$(uname -s)" = Darwin ] || { printf 'Build this on macOS.\n' >&2; exit 1; }
sdk="$(xcrun --sdk macosx --show-sdk-path)"
native_arch="$(uname -m)"
sparkle_dir="$(bash scripts/fetch-sparkle.sh)"
mkdir -p build
xcrun swiftc -swift-version 5 -sdk "$sdk" -target "${native_arch}-apple-macos13.0" \
    Sources/Models.swift Tests/LoopTimeTests.swift -o build/LoopTimeTests
build/LoopTimeTests
stage="$(mktemp -d "$PWD/build/app.XXXXXX")"
bundle="$stage/Ambience.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources" "$bundle/Contents/Frameworks"
cp Info.plist "$bundle/Contents/Info.plist"
cp Resources/catalog.json "$bundle/Contents/Resources/catalog.json"
if [ -f Resources/PipBear.png ]; then cp Resources/PipBear.png "$bundle/Contents/Resources/PipBear.png"; fi
ditto "$sparkle_dir/Sparkle.framework" "$bundle/Contents/Frameworks/Sparkle.framework"
if [ -f "$sparkle_dir/LICENSE" ]; then cp "$sparkle_dir/LICENSE" "$bundle/Contents/Resources/Sparkle-LICENSE.txt"; fi
if [ -f Config/update-public-key.txt ]; then
    python3 - "$bundle/Contents/Info.plist" <<'PY'
import base64, pathlib, plistlib, sys
key = pathlib.Path('Config/update-public-key.txt').read_text().strip()
if len(base64.b64decode(key, validate=True)) != 32:
    raise SystemExit('The update public key must be a base64-encoded 32-byte Ed25519 key.')
path = pathlib.Path(sys.argv[1])
data = plistlib.loads(path.read_bytes())
data['SUPublicEDKey'] = key
path.write_bytes(plistlib.dumps(data))
PY
elif [ "${1:-}" = --release ]; then
    printf 'Release blocked: run Setup-Publishing.command to configure signed updates first.\n' >&2
    exit 1
fi
architectures=("$native_arch")
if [ "${1:-}" = --release ]; then architectures=(arm64 x86_64); fi
for target_arch in "${architectures[@]}"; do
    printf 'Compiling Ambience for %s…\n' "$target_arch"
    xcrun swiftc -swift-version 5 -O -sdk "$sdk" -target "${target_arch}-apple-macos13.0" \
        -module-cache-path "$PWD/build/ModuleCache" -F "$sparkle_dir" \
        -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
        Sources/*.swift \
        -framework AppKit -framework SwiftUI -framework AVFoundation -framework QuartzCore \
        -framework IOKit -framework ServiceManagement -framework UniformTypeIdentifiers -framework Sparkle \
        -o "$stage/Ambience-$target_arch"
done
if [ "${1:-}" = --release ]; then
    lipo -create "$stage/Ambience-arm64" "$stage/Ambience-x86_64" -output "$bundle/Contents/MacOS/Ambience"
else
    cp "$stage/Ambience-$native_arch" "$bundle/Contents/MacOS/Ambience"
fi
# Preserve Sparkle's own signatures; ad-hoc sign only the containing app, without hardened runtime.
codesign --force --sign - "$bundle"
codesign --verify --deep --strict "$bundle"
if [ -d build/Ambience.app ]; then rm -rf build/Ambience.app; fi
mv "$bundle" build/Ambience.app
printf 'App built: %s/build/Ambience.app\n' "$PWD"
