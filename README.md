# Clippy

A clipboard history in your menu bar. Click the clipboard icon (or press ⌥⌘V) to see your recent clips; click one to put it back on the clipboard. Works on every display.

No Dock icon. Right-click the menu bar icon for Settings and Quit.

> The first version was called NotchClip and lived in the MacBook notch. See [DECISIONS.md](DECISIONS.md) for why it moved to the menu bar.

## Requirements

- macOS 14 or later (built and tested on macOS 27 with Xcode 26.6, Swift 6.3)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

```sh
./run.sh
```

This generates the Xcode project, builds it, quits any running copy and opens the new build. The `.xcodeproj` is generated from `project.yml` and isn't checked in.

Run the tests:

```sh
xcodebuild test -scheme Clippy -destination 'platform=macOS' -derivedDataPath build
```

## Sharing the app

```sh
./package.sh
```

This builds a universal Release (Apple Silicon and Intel, macOS 14+) and writes the file to share:

```
dist/Clippy.zip
```

Reveal it in Finder with `open -R dist/Clippy.zip`. The zip isn't checked in; run `./package.sh` again after any change so it contains the latest build.

The app isn't notarized by Apple (that needs a paid Developer ID), so the first launch on someone else's Mac is blocked with "Apple could not verify Clippy…". To open it:

1. Unzip and move **Clippy.app** to Applications.
2. Double-click it, then click **Done** on the warning.
3. Open **System Settings › Privacy & Security**, scroll down and click **Open Anyway** next to the Clippy message, then confirm.

After that it opens normally. (Terminal alternative: `xattr -dr com.apple.quarantine /Applications/Clippy.app`.)

## Using it

| Action | How |
|---|---|
| Open / close | Click the menu bar icon, or ⌥⌘V (changeable in Settings) |
| Copy an item back | Click its row, or select it and press Return |
| Quick copy | ⌘1 … ⌘9 |
| Move selection | ↑ / ↓ |
| Delete | Hover a row and click ×, or select it and press ⌫ |
| Pin / unpin | Hover a row and click the pin; pinned items stay at the top and are never evicted |
| Search | ⌘F or the magnifier; matches text, URLs, file names and source app |
| More options | Right-click a row (Copy as Plain Text, Pin, Delete) |
| Close | Esc, click outside, or click the icon again |
| Settings / Quit | Gear in the list, or right-click the menu bar icon |

On MacBooks with a notch, a crowded menu bar can hide icons behind the notch. If the clipboard icon is hidden, ⌥⌘V still opens the list at the top right of the screen; tools like Ice or Bartender can manage which icons show.

## Privacy

- Items that password managers mark as concealed, transient or auto-generated ([nspasteboard.org](http://nspasteboard.org) types) are never recorded.
- Copies made in ignored apps are never recorded. Defaults: 1Password, Bitwarden, Keychain Access, Passwords. Edit the list in Settings.
- History stays on your Mac in `~/Library/Application Support/Clippy/` (`history.json` plus an `images/` folder). Nothing is sent anywhere.
- On macOS 15.4+, if you set Clippy to **Deny** under System Settings › Privacy & Security › Paste from Other Apps, it stops reading the clipboard and shows a card in the panel explaining how to allow it.

## Not sandboxed

Clippy v1 is **not sandboxed** and is ad-hoc signed. That keeps clipboard monitoring and launch-at-login simple, but it also means:

- Launch at login (`SMAppService`) may be refused or need approval in System Settings › General › Login Items, especially when running from the build folder. Copy the app to `/Applications` first.
- Gatekeeper blocks the first launch on other Macs; see [Sharing the app](#sharing-the-app).

## Project layout

```
Clippy/
  App/        App entry point and AppDelegate (wires everything together)
  Window/     Menu bar icon, dropdown panel, positioning, keyboard and outside-click handling
  Views/      Panel model and view, header, list, rows, settings
  Model/      ClipItem, ClipboardStore (persistence, dedupe, limits), AppSettings
  Services/   PasteboardMonitor + PasteboardCodec (read/classify/write), LaunchAtLogin
ClippyTests/  Store and classification tests (Swift Testing)
```

Design decisions and deviations from the original spec are in [DECISIONS.md](DECISIONS.md).
