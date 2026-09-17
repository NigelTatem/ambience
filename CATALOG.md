# Publishing downloadable wallpapers

Discover reads Resources/catalog.json from NigelTatem/ambience's main branch over HTTPS. It falls back to the copy bundled with the app if unavailable. The starter catalog is empty: no unlicensed videos or invented download links are included.

Use MP4 files with playback-compatible video/audio codecs. List only resolutions the file actually contains; 1440p means 2560×1440, not a relabeled 1080p file. Prefer short, intentional loops over hour-long downloads. Keep each file under 2 GiB.

For each wallpaper, host a thumbnail and MP4 variants at stable public HTTPS URLs. Keep a record of permission/license, credit the creator, then add a catalog entry with this shape:

```json
{
  "schemaVersion": 1,
  "wallpapers": [
    {
      "id": "unique-slug",
      "title": "Wallpaper title",
      "creator": "Creator name",
      "license": "Your actual redistribution permission or license",
      "sourceURL": "https://creator.example/source-page",
      "thumbnailURL": "https://hosting.example/thumbnail.jpg",
      "variants": [
        {
          "id": "1080p",
          "label": "1080p",
          "width": 1920,
          "height": 1080,
          "bytes": 12345678,
          "sha256": "REPLACE_WITH_THE_REAL_64_CHARACTER_SHA256",
          "url": "https://hosting.example/wallpaper-1080p.mp4"
        }
      ]
    }
  ]
}
```

The example above is documentation, not a live catalog entry. Use `shasum -a 256 video.mp4` for the checksum and `stat -f%z video.mp4` on Mac for the byte count. Add 1440p and 4K variants when available, with their own size and checksum. Keep the smallest version first; it is the default download.

Commit the real JSON to main. Users can click Refresh in Discover without updating Ambience. Download & Apply verifies the byte count and SHA-256, then imports a local copy and applies it. Creator/license/source credits remain attached to the imported clip. Remote files are decoded as media only; the catalog cannot install app updates or execute programs.

Do not hotlink a creator's files or mirror game/YouTube videos without appropriate permission. Start with your own footage or expressly redistributable material.
