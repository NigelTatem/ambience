# One-time publishing setup for NigelTatem

No App Store or paid Apple developer account is used. GitHub's standard hosted runners are free for public repositories. The repository created by the setup script is public.

## First run

1. Extract this source package one final time into its own folder. Quit the old Ambience app.
2. Run **Setup-Publishing.command**. It requires Apple's Command Line Tools and GitHub CLI. If Homebrew is present, the script installs missing GitHub CLI with `brew install gh`; otherwise it opens the official GitHub CLI installation page and asks you to run setup again afterward.
3. Sign into GitHub as **NigelTatem** in the browser when prompted. If an existing CLI login cannot push workflow files, run `gh auth refresh -h github.com -s workflow`, then retry.
4. Allow Sparkle's key-generation tool to access your login Keychain. It generates or reuses an app-specific Ed25519 key; it does not buy an Apple certificate.
5. The script builds locally before uploading source, creates **NigelTatem/ambience** if absent, saves the private key as the repository's **SPARKLE_PRIVATE_KEY** Actions secret, pushes source and a version tag, and installs your updater-enabled local build.
6. GitHub Actions builds a universal Apple Silicon/Intel app, verifies its archive signature against the embedded public key, and creates a **draft release** containing a DMG, update ZIP, appcast.xml, and checksums. It does not publish the release automatically.
7. Download and test the DMG from that draft, including playback, framing, sound, sleep, and launch at login. Publish the tested draft as a normal **Latest** release. Do not mark it a prerelease: GitHub's `/releases/latest` ignores prereleases.

The first setup still needs one extraction because the existing personal app has no updater. After the new build is installed and the first release is published, app users can update from the app without extracting projects or compiling.

## Future versions

Work in the Git repository produced by setup. Commit changes, increase BOTH CFBundleShortVersionString and the numeric CFBundleVersion in Info.plist, and edit RELEASE-NOTES.md. Push main, tag the same version (for example v1.2.1), and push that tag. The release workflow makes a new draft. Test it, then publish it as Latest. A published version's files must not be replaced; make a new version instead.

For a failed build, open the run in the Actions tab and share its compiler error with ChatGPT. A workflow_dispatch run can retry packaging the currently selected source version; the workflow refuses to overwrite a published release or an existing draft from a different commit.

**Test an actual update before promoting the app:** install the first updater-enabled release, publish a second higher-version release, use Check for Updates, and confirm replacement, relaunch, and saved settings. Until this succeeds, automatic updating is implemented but unverified.

## Keep these private

The private update key belongs in your Mac's Keychain and GitHub Actions secrets only. Never put it in Git, a screenshot, chat, release assets, or the app. The public key in Config/update-public-key.txt is safe and must match the private signing key. Setup stops rather than replacing an existing public key with a different key.

Keep a secure backup of the Keychain key. Losing it can prevent existing free builds from accepting future updates. All workflow code with access to this secret must remain trusted. Do not expose this secret to pull requests from forks.

## Hosting and costs

App files and the update feed are GitHub release assets. The catalog JSON is read from the public repository's main branch, so gallery changes do not need an app release. Wallpaper video hosting is separate; add only files you can redistribute and use hosting with suitable bandwidth limits. There is no paid media host configured by this package.

No open-source license has been selected for the project's source yet; publishing source does not require choosing one immediately. Third-party wallpapers retain their own licenses. A paid Apple Developer ID/notarization setup is an optional later improvement for first-install friction, not used here.

References: [Sparkle setup](https://sparkle-project.org/documentation/), [GitHub public runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners), [GitHub releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
