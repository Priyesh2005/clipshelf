# ClipShelf

A free native macOS clipboard history app. Copy once, find it again, click to copy and return to your app.

## Download

[Download ClipShelf 0.1.0](https://github.com/Priyesh2005/clipshelf/releases/download/v0.1.0/ClipShelf-0.1.0-macOS.zip) · [Releases](https://github.com/Priyesh2005/clipshelf/releases)

macOS 13+. Universal binary for Apple silicon and Intel. Apple silicon tested locally; Intel and older macOS versions still need device testing. The early beta is ad-hoc signed, not Developer ID signed or Apple-notarized. macOS may block its first launch. Review [Apple's guidance](https://support.apple.com/en-us/102445) before approving a download you trust. Do not disable Gatekeeper.

Unzip the download, move ClipShelf.app to Applications and open it. Choose Start Recording. Press **Control–Option–V**, click an entry, then **Command–V** to paste.

## Terminal installation

Review [install.sh](install.sh) before running:

```sh
curl -fsSL https://raw.githubusercontent.com/Priyesh2005/clipshelf/main/install.sh | bash
```

The installer checks the OS and architecture, downloads the pinned release, verifies its SHA-256 and code signature, and installs to `~/Applications`. It preserves first-launch checks, requires no sudo, and refuses to overwrite an existing app. It does not start recording automatically.

## Features and privacy

- Last 200 plain-text entries; maximum 100 KB per entry.
- Search, single-click copying and keyboard selection.
- Shortcut choices, pause/resume, clear history and optional Launch at Login.
- Local data at `~/Library/Application Support/ClipShelfPublic/history.json`.
- No network calls, analytics or accounts in the app.
- History has owner-only file permissions but no app-level encryption. Known confidential clipboard markers are skipped; ordinary sensitive text may still be stored.
- Text only. No image/file history or rich-text formatting. Very rapid changes can be missed between 0.4-second clipboard checks.

## Build

Install Apple Command Line Tools, then run:

```sh
cd app
./build.sh
```

The build compiles Apple silicon + Intel slices, signs locally, tests history behavior and packages a ZIP. It does not notarize the app. See [app/README.md](app/README.md).

## Website

Static HTML/CSS/JavaScript in `site/`, deployed on Vercel using `vercel.json`. Fonts are self-hosted under the SIL Open Font License; their licenses are in `site/assets/fonts/`. Actual app screenshots use isolated demonstration entries, not personal clipboard history. Design study: [docs/design-study.txt](docs/design-study.txt).

## Uninstall

Disable Launch at Login, quit the app and delete it. Remove `~/Library/Application Support/ClipShelfPublic` to delete saved history as well.

## License

MIT for app, installer and website code. Font licenses are included separately.
