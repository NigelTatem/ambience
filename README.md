# Ambience

Free, customizable video wallpapers for macOS Ventura 13 and later.

- Local MP4/MOV playback with ambience audio and adjustable loops.
- Per-video zoom, position, Fit/Fill, and a draggable framing preview.
- Launch at login, power-saving pauses, and offline playback.
- Built-in Sparkle updates with signed update archives.
- Discover tab for publisher-approved videos, resolution choices, and creator credits.

## Download

When the first tested release is published, download the DMG from [Releases](https://github.com/NigelTatem/ambience/releases/latest). Open it and drag Ambience to Applications. You do not need Xcode, a compiler, a subscription, or an Ambience account.

These free builds are ad-hoc signed, not Apple-notarized. macOS may require you to approve the first launch in System Settings → Privacy & Security. See [Apple's guidance](https://support.apple.com/en-us/102445). Do not disable Gatekeeper globally.

After installing an updater-enabled release, use the leaf menu → Check for Updates. Automatic checks are optional. Updates retain the collection and settings stored in ~/Library/Application Support/Ambience.

## Development and publishing

- Run `Build-and-Run.command` to build locally with Apple's free Command Line Tools.
- The publisher runs `Setup-Publishing.command` once. See [PUBLISHING.md](PUBLISHING.md).
- Wallpaper catalog instructions are in [CATALOG.md](CATALOG.md).
- Detailed playback instructions are in [START-HERE.md](START-HERE.md).

The app is free to use. No open-source license has been selected for this project's source yet. Third-party wallpapers retain their own licenses. Sparkle is MIT-licensed and its license is included in the built app. No game videos are bundled.

## Status

The earlier personal build has been run by its owner. The new release workflow, updater, and catalog download flow still require macOS compilation and an end-to-end release test. The initial Discover catalog is intentionally empty pending approved media.
