# Decisions

## Menu bar instead of the notch (2026-10-08)

The original spec put the UI in the MacBook notch. In use, the panel only appeared on the built-in display, so it was missing when working on an external monitor. The notch UI was **replaced** by a menu bar icon (`NSStatusItem`) that opens the same list in a dropdown. The menu bar exists on every display, so this works everywhere. Removed: the notch shape and hover/expand animations, notch detection, click-through mouse tracking, and the "Show on" display setting.

## Renamed NotchClip → Clippy (2026-10-08)

With the notch gone, the app is now **Clippy** (bundle ID `in.f9x.Clippy`, folders `Clippy/` and `ClippyTests/`). On first launch, `AppDelegate.migrateFromNotchClip()` moves `~/Library/Application Support/NotchClip` to `…/Clippy` and copies the `in.f9x.NotchClip` preferences (history limit, hotkey, ignored apps) into the new domain. It never overwrites existing Clippy data. The old preferences file is left in place.

- **Dropdown is a non-activating `NSPanel`, not an `NSPopover`.** A popover has to activate the app to get keyboard input, which takes focus from the app you're copying into. The panel becomes key without activating, so ↑/↓/Return/Esc work and typing goes back to your app when it closes.
- **Left-click toggles the list; right-click shows Settings… / Quit.** The menu is attached only for the right-click (`statusItem.menu` set, `performClick`, cleared) so left-click stays free.
- **Clicks on the icon arrive at the global mouse monitor.** On macOS 27 the menu bar is drawn by another process, so a click on our own icon looks like an outside click. The outside-click monitor ignores clicks inside the icon's frame and lets the icon's action toggle; otherwise clicking the icon while open closed and immediately reopened the panel.
- **Placement:** on the display with the mouse. Under the icon if the icon is on that display; otherwise top-right of the display. That covers the hotkey and the case where the icon is hidden (on notch Macs, crowded menu bars push icons behind the notch).
- **"Copied" check shows for 0.6s** (was 0.9s) before the list closes; a dropdown that lingers feels slow.

## General

- **Not sandboxed (v1).** No entitlements file, so pasteboard reading and launch-at-login need no extra setup.
- **Ad-hoc signing** (`CODE_SIGN_IDENTITY = "-"`) so it builds from the CLI with no developer account.
- **Generated `.xcodeproj` is git-ignored.** `project.yml` is the source of truth; run `xcodegen` after cloning. KeyboardShortcuts is pinned to an exact version there, since `Package.resolved` lives inside the ignored project.
- **Unit tests run hosted in the app**; `AppDelegate` skips all setup when `XCTestConfigurationFilePath` is set, so tests never read the real clipboard or write real history. Codec tests use `NSPasteboard.withUniqueName()`.

## Clipboard

- **Pasteboard polling** uses a 0.4s `Timer` on the main run loop in `.common` mode. Reading `changeCount` is an integer check, so the main actor is fine and avoids cross-actor hops under Swift 6.
- **Classification order:** files, images, URLs, rich text, **colors, then plain text**. Colors come before plain text because apps that copy a color usually add its text form too, which would otherwise always win. A plain-text copy that is exactly one http(s) URL is classified as a URL.
- **Oversized content is skipped, not truncated** (text > 1MB, image PNG > 10MB). A truncated copy would paste back different content.
- **Dedupe hash** covers the visible payload only (e.g. plain text for both rich and plain text), so the same text copied from two apps is one item. Dedupe moves the existing item to the top with a fresh timestamp, keeping its pin.
- **Copy-back** moves the item to the top (`bump`) and records the resulting `changeCount` so the monitor ignores it.
- **Pasteboard access (macOS 15.4+):** when `NSPasteboard.accessBehavior` is `.alwaysDeny`, the monitor stops reading and the list shows an inline card. The card opens the Privacy & Security pane; there is no documented deep link to the "Paste from Other Apps" list itself.
- **Ignored apps defaults** (bundle IDs): `com.1password.1password`, `com.agilebits.onepassword7`, `com.bitwarden.desktop`, `com.apple.keychainaccess`, `com.apple.Passwords`.

## Storage

- **"Clear history" keeps pinned items.** Pins are explicit "keep this" signals.
- **Corrupt `history.json`** is renamed to `history.corrupt-<ts>.json` instead of being overwritten on the next save.
- **Dates** are stored as JSON's default `Double` (not ISO 8601), so they round-trip exactly.

## List UI

- **Actions live on `PanelModel`** (copy, delete, pin, selection), shared by mouse and keyboard; the "Copied" check is driven by `copiedID` so keyboard copies show it too.
- **Keyboard handling** lives in the panel's local `keyDown` monitor, which runs before the search field's field editor. ↑/↓/Return/⌘F/⌘1–9/Esc are always handled; ⌫ deletes the selected item only when the search field is *not* focused, so it can still edit the query.
- **Selection** starts on the first visible item when the list opens and resets to the first match whenever the query changes, so Return always copies something sensible.
- **Search resets when the list closes.**
- **Row stagger** uses one `revealed` flag on the list, flipped on first appear; each row animates with `0.09s + index × 25ms` delay (capped at 10 rows). Rows created later by `LazyVStack` while scrolling don't re-animate.
- **Thumbnails** are downsampled with ImageIO (max 240px) and cached with app/file icons in `NSCache` (`IconCache`), so a 5K screenshot is never fully decoded for a 44pt row.
- **Relative timestamps** come from a single `TimelineView` (30s period) around the list rather than per-row timers.
- **"Code-looking" text** (SF Mono) is a marker heuristic: `{ } ; => -> () </`, a tab, or 4-space indentation.
- **Reduce Motion** is checked per animation via `NSWorkspace.accessibilityDisplayShouldReduceMotion` (row springs become 0.15s ease, the panel fade is instant).

## Settings

- **Settings** are a plain `NSWindow` + `NSHostingController` (`SettingsWindowController`), not a SwiftUI `Settings` scene, which is unreliable to open from an `LSUIElement` app. Opening it activates the app; the list closes first.
- **`AppSettings`** (UserDefaults-backed `@Observable`) is read directly by the monitor (ignored apps) and the panel model (close after copy). History limit is pushed into `ClipboardStore.limit` from the picker.
- **Hotkey** uses KeyboardShortcuts 2.4.0 (`togglePanel`, default ⌥⌘V), with its recorder in Settings.
- **Launch at login** uses `SMAppService.mainApp`. With an ad-hoc-signed build outside /Applications the system may refuse or require approval; the toggle shows the error or an approval hint and reverts if registration fails.
