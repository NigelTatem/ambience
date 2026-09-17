# Ambience for Mac

A free, personal menu-bar app for local video wallpapers with sound. Requires macOS Ventura 13 or later. Builds for Apple Silicon or Intel using Apple's free Command Line Tools. No paid developer account, Xcode app, Homebrew, or subscription is needed.

## Run it

For the new download/update setup, the publisher should run **Setup-Publishing.command** once instead. See **PUBLISHING.md**. Followers will install the compiled DMG from GitHub, without running these source-build steps.

1. Extract the ZIP and open the Ambience folder.
2. Double-click **Build-and-Run.command**. If macOS requests Command Line Tools, install them and run the script again afterward.
3. In Ambience, click **Add Videos** and choose your MP4s or MOVs. H.264 MP4 with AAC audio is a good starting format.
4. The app starts the first video's first two minutes, or its full length if shorter. Sound starts at 15% volume. Use Pause or Mute any time.
5. Turn on **Launch at login** if wanted. It starts after you sign in, not before login or on the lock screen. macOS may ask you to approve it in Login Items.

The installed app is **~/Applications/Ambience.app**. Open it there afterward; rebuilding is only necessary for updates. The installer retains the previous app as a dated backup when updating.

If Finder says the command lacks permission, open Terminal and run:

```bash
cd ~/Downloads/Ambience
bash Build-and-Run.command
```

If you extracted elsewhere, type `bash ` into Terminal, drag **Build-and-Run.command** into the Terminal window, and press Return. If macOS blocks a downloaded script, inspect it first and use the specific Open Anyway option in System Settings → Privacy & Security if you trust it. You do not need to disable Gatekeeper globally.

## Use your collection

- **Frame your world** lets you drag the still preview to reposition the video, or use the Left / Right and Up / Down sliders. **Zoom** ranges from 50% to 300%. Changes apply to your desktop immediately, and each video remembers its own framing after you release the drag or slider. The preview matches the main display's aspect ratio. Optional rule-of-thirds guides appear only in the preview.
- **Fit** resets to an uncropped, centered picture. **Fill** resets to a centered image that covers the screen and crops any excess. Both reset zoom to 100%. **Center** resets position while keeping your zoom and Fit/Fill choice. Moving or shrinking the video can expose black margins; the picture is never stretched.
- Click the **leaf in the menu bar** to pause, mute, go to the next video, or select one directly.
- Closing the collection window leaves the wallpaper playing. **Quit Ambience** stops video and sound and reveals your normal wallpaper.
- Import more MP4/MOV files with **Add Videos**. Each is copied into Ambience's own folder, so moving the original won't break it.
- Select a video and enter start/end times as seconds, `m:ss`, or `h:mm:ss`. Click **Save & Apply**. Presets choose 30 seconds, two minutes, or the whole video; presets also need Save & Apply.
- The picture in the collection is a still preview of the saved start. Watch the actual moving wallpaper on your desktop.
- **Export Saved Loop** creates a separate MP4 at up to 1080p, retaining audio. It trims the saved time range only: your desktop zoom and position are not applied to the exported file. Exporting re-encodes; it may take time and use more energy temporarily. The original stays intact. Save your loop edits before exporting.
- Looping a selected time range does not shrink the imported source file. To save disk space, export a short clip, import the export, then remove the long copy from Ambience.
- Removing a video removes the app's imported copy, not the original you chose.

## Power and playback

The app uses AVQueuePlayer and AVPlayerLooper, Apple's native playback APIs, and plays on the main display behind desktop icons. It does not run a browser or render custom animations. Hardware decoding depends on the source codec and your Mac.

It pauses video and sound when the Mac or display sleeps and when the user session becomes inactive. Pause in Low Power Mode is on by default. Optional Pause on battery responds within about 30 seconds. Manual pause, mute, volume, video selection, and loop ranges are saved across launches.

Video wallpaper still uses energy. Start with 1080p at 24 or 30 fps; shorter duration mainly saves storage, while resolution, frame rate, and codec affect decoding cost. This version does not detect covering windows or automatically pause behind a full-screen app. Battery impact has not been measured.

Arbitrary video/audio cuts are not guaranteed to sound or look seamless. Pick similar visual endpoints and avoid cutting in the middle of a musical phrase. There is no crossfade in this version. Entire hour-long videos can loop too.

## Video sources

Use your own local videos or downloads the creator provides. This package contains no game art or videos and does not download YouTube videos. Your reference is available from the empty collection screen:

https://youtu.be/h5wBQzhqLYQ

## Troubleshooting

- **Build error:** copy the complete compiler error into ChatGPT. Build output stays in the Terminal window until you press Return.
- **No wallpaper:** open the leaf menu, check Pause, battery settings, and Low Power Mode. Try a standard H.264 MP4. This version targets the main desktop, not lock screens or every external monitor. Spaces/Stage Manager behavior needs to be checked on your macOS version.
- **No audio:** check the app's mute button, volume slider, macOS output device, and whether the source video contains audio.
- **Launch at login won't enable:** add the installed app manually in System Settings → General → Login Items. If you rebuild the app, recheck this setting.
- **Quit:** use the leaf menu → Quit Ambience. If unresponsive, use Activity Monitor to quit the process named Ambience.
- **Reset or uninstall:** quit Ambience, turn off/remove its login item, and move ~/Applications/Ambience.app to Trash. Its saved video copies and settings are in ~/Library/Application Support/Ambience. Keep that folder if you want your collection later, or remove it yourself to reclaim space. The Show video folder button opens it.

## Validation status

Version 1.2.0 adds Sparkle update controls, a Discover tab, and a GitHub publishing workflow. Existing videos, loop ranges, framing, and power settings are preserved. An initial publisher setup and release are required before updates work. The first Discover catalog has no wallpapers yet; approved media can be added independently of app updates.

The new update/distribution code was authored in a Linux environment without Apple's SDK. Swift source syntax, shell syntax, the app manifest, feed generation, and packaging were checked here. Syntax parsing does not check Apple API types. Earlier personal builds have run on the owner's Mac, but **this release's updater, catalog downloads, and GitHub build workflow have not been run on macOS yet**. Local setup and GitHub Actions compile the sources and run model checks. Before public promotion, complete the smoke check below and a real old-to-new update test.

## Mac smoke check

1. Import a short MP4 with sound. Confirm that desktop icons remain clickable.
2. Set a nonzero start/end and listen through a repeat.
3. Add a second video and switch with the leaf menu. Confirm the first video's sound stops.
4. Pause, mute, change volume, quit and relaunch. Confirm the settings and selected video persist.
5. Export a saved section and check its duration and audio in QuickTime Player.
6. Sleep/wake and check power settings. Enable launch at login and sign out/in when convenient.
7. Drag right and down in the preview and verify the desktop moves the same way. Try zoom, then switch between two videos with different framing. Quit/relaunch to check their framing persists. Use Fit to reset to the whole picture.

API references: [AVPlayerLooper](https://developer.apple.com/documentation/avfoundation/avplayerlooper), [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice), [NSWindow](https://developer.apple.com/documentation/appkit/nswindow).
