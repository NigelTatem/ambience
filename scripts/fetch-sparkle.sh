#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
cache="$PWD/.cache/Sparkle-$version"
archive="$cache/Sparkle-$version.tar.xz"
mkdir -p "$cache"
if [ ! -f "$archive" ]; then
    printf 'Downloading Sparkle %s from its official release…\n' "$version" >&2
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 \
        "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" \
        -o "$archive.partial" >&2
    mv "$archive.partial" "$archive"
fi
printf '%s  %s\n' "$checksum" "$archive" | shasum -a 256 -c - >&2
if [ ! -d "$cache/Sparkle.framework" ]; then
    tar -xf "$archive" -C "$cache"
fi
printf '%s\n' "$cache"
