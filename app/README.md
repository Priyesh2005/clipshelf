# ClipShelf — public beta 0.1.0

Free native macOS text clipboard history. MIT licensed. No account, subscription, network calls, or analytics in the app.

## Requirements and installation

macOS 13 Ventura or later. Universal executable includes Apple silicon and Intel architectures. Tested locally on Apple silicon; Intel and older supported macOS versions still need device testing.

Download and unzip ClipShelf-0.1.0-macOS.zip, move ClipShelf.app into Applications, then open it. This beta is ad-hoc signed, NOT signed with an Apple Developer ID or notarized. macOS may block the first launch. Review Apple's guidance at https://support.apple.com/en-us/102445 before deciding whether to allow it in System Settings → Privacy & Security → Open Anyway. Only proceed if you trust the download. Do not disable Gatekeeper. Organization-managed Macs may not permit this beta.

Choose Start Recording on first launch. Press Control–Option–V to open history. Single-click an item to copy it, close the window and return to the previous app; press Command–V to paste. Arrow keys + Return also work.

Right-click the menu bar icon for shortcut choices, pause/resume, launch at login, clear history, or quit. Command–S is optional and overrides Save while the app runs. Launch at Login may depend on macOS approval and is not verified on all supported versions.

## Privacy and limits

Stores the last 200 text entries, maximum 100 KB each, at ~/Library/Application Support/ClipShelfPublic/history.json. Stored as JSON with owner-only file permissions, without app-level encryption. There are no network calls or analytics in the app. Clipboard history begins only after recording is enabled while the app runs; it does not import Spotlight history. Checks for clipboard changes every 0.4 seconds, so rapidly overwritten items can be missed. Text only; images, files and original rich-text formatting are not retained.

Known confidential/transient pasteboard types are skipped. This does not detect every secret: ordinary copied passwords or private text can be stored. Pause or clear history whenever needed. The download website is hosted separately and its provider may process normal request logs.

## Build

Install Apple's Command Line Tools, then run `./build.sh`. It builds both architectures, runs history tests and creates the ZIP plus SHA-256 checksum in release/. The source archive contains code and assets only, never personal clipboard history.

## Remove

Disable Launch at Login if enabled, quit from the menu bar, and delete the app. Delete ~/Library/Application Support/ClipShelfPublic to remove stored history.
