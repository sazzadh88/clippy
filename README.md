# NotchClip

A clipboard history that lives in the MacBook notch. Hover the notch and it grows slightly; click it (or press ⌥⌘V) and a black panel springs out of the notch with your recent clips. Click a row to put it back on the clipboard.

No Dock icon, no menu bar item: right-click the notch for Settings and Quit.

## Requirements

- macOS 14 or later (built and tested on macOS 27 with Xcode 26.6, Swift 6.3)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

```sh
xcodegen
xcodebuild -scheme NotchClip -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/NotchClip.app
```

The `.xcodeproj` is generated from `project.yml` and isn't checked in. Run `xcodegen` again after adding or removing files.

Run the tests:

```sh
xcodebuild test -scheme NotchClip -destination 'platform=macOS' -derivedDataPath build
```

## Using it

| Action | How |
|---|---|
| Open / close | Click the notch, or ⌥⌘V (changeable in Settings) |
| Copy an item back | Click its row, or select it and press Return |
| Quick copy | ⌘1 … ⌘9 |
| Move selection | ↑ / ↓ |
| Delete | Hover a row and click ×, or select it and press ⌫ |
| Pin / unpin | Hover a row and click the pin; pinned items stay at the top and are never evicted |
| Search | ⌘F or the magnifier; matches text, URLs, file names and source app |
| More options | Right-click a row (Copy as Plain Text, Pin, Delete) |
| Close | Esc, click outside, or move the mouse away from the panel |
| Settings / Quit | Gear in the panel, or right-click the notch |

On a Mac without a notch (or an external display), NotchClip shows a small black pill at the top center of the screen instead.

## Privacy

- Items that password managers mark as concealed, transient or auto-generated ([nspasteboard.org](http://nspasteboard.org) types) are never recorded.
- Copies made in ignored apps are never recorded. Defaults: 1Password, Bitwarden, Keychain Access, Passwords. Edit the list in Settings.
- History stays on your Mac in `~/Library/Application Support/NotchClip/` (`history.json` plus an `images/` folder). Nothing is sent anywhere.
- On macOS 15.4+, if you set NotchClip to **Deny** under System Settings › Privacy & Security › Paste from Other Apps, it stops reading the clipboard and shows a card in the panel explaining how to allow it.

## Not sandboxed

NotchClip v1 is **not sandboxed** and is ad-hoc signed. That keeps clipboard monitoring and launch-at-login simple, but it also means:

- Launch at login (`SMAppService`) may be refused or need approval in System Settings › General › Login Items, especially when running from the build folder. Copy the app to `/Applications` first.
- Gatekeeper may warn the first time you open a copy of the app on another Mac.

## Project layout

```
NotchClip/
  App/        App entry point and AppDelegate (wires everything together)
  Window/     NSPanel, positioning, mouse tracking/click-through, notch detection
  Views/      Notch shape and state machine, header, list, rows, settings
  Model/      ClipItem, ClipboardStore (persistence, dedupe, limits), AppSettings
  Services/   PasteboardMonitor + PasteboardCodec (read/classify/write), LaunchAtLogin
NotchClipTests/  Store and classification tests (Swift Testing)
```

Design decisions and deviations from the original spec are in [DECISIONS.md](DECISIONS.md).
