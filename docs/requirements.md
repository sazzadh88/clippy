# Build "NotchClip" — a macOS clipboard history app that lives in the notch

You are building a native macOS app from scratch in this empty directory. Work autonomously
through the milestones below, building and fixing compile errors as you go. Do not stop to ask
questions unless something is truly blocking; make a sensible decision, note it in DECISIONS.md,
and continue.

## 1. Goal

A menu-bar-less agent app that visually merges with the MacBook notch. Hovering the notch makes
it subtly "breathe" outward. Clicking it expands a black panel out of the notch showing clipboard
history. The user can click an item to copy it back to the clipboard, delete items, pin items,
search, and clear history. Clicking outside or moving the mouse away collapses it.

## 2. Visual & motion reference (match this feel closely)

Reference: https://github.com/Louis-CFM/coucou (demo: docs/media/demo.gif). Emulate the STYLE and
MOTION only. Do NOT copy its mascot ("Mochi"), name, icons, sounds or any assets — they are not
licensed for reuse. No mascot is needed at all.

What the reference does, frame by frame:

- **Collapsed:** the window is exactly the size/shape of the hardware notch, pure black (#000),
  so it is invisible. Optional: a tiny indicator on each side (e.g. a small clipboard glyph on the
  left, item count on the right) that extend the notch horizontally by ~30pt per side, like
  "wings".
- **Hover:** the notch shape grows slightly (≈ +12pt wider, +4pt taller) with a soft spring, and
  a faint white glow/shadow appears. Moving away reverses it.
- **Expand (click):** the black shape grows downward AND outward from the notch into a wide panel
  (~620×300pt). The top edge stays flush with the screen top. The top corners use small INVERSE
  ("ear") curves where it meets the menu bar, and the bottom corners use a large continuous radius
  (~24pt). Use a spring with a noticeable but small overshoot
  (e.g. `.spring(response: 0.42, dampingFraction: 0.78)`).
- **Content reveal:** content appears only AFTER the shape is ~60% expanded: opacity 0→1,
  scale 0.96→1, blur 6→0, slightly staggered per row (~25ms apart). On collapse, content fades out
  first (fast, ~120ms), then the shape shrinks back into the notch.
- **Layout inside the panel:** a slim header row (height ~28pt). Left side: small SF Symbols
  (clipboard, pin, search). Right side: a trash "clear all" button and a gear. All icons are white
  at ~55% opacity, 100% on hover. Below the header is the content area: dark cards
  (#1C1C1E / white 8% opacity) with ~14pt continuous corner radius and 8–10pt gaps.
- **Typography:** SF Pro, 12–13pt for item text, 10–11pt secondary text (white 45% opacity);
  SF Mono for code-looking snippets. Pill-shaped secondary buttons.
- **Overall:** pure black panel, high contrast, no window chrome, no visible borders except an
  optional 0.5pt white-6% hairline on cards.

## 3. Tech stack & constraints

- Swift 6, SwiftUI for views, AppKit for windowing. Target macOS 14+.
- Generate the Xcode project with **XcodeGen** (`project.yml`). Install it with
  `brew install xcodegen` if missing. Do not hand-edit .pbxproj files.
- App is an agent: `LSUIElement = YES` (no Dock icon, no main menu bar).
- No third-party dependencies unless clearly justified (KeyboardShortcuts by sindresorhus is
  acceptable for the global hotkey).
- Not sandboxed for v1 (simplifies pasteboard and launch-at-login). Note this in README.
- Build from the CLI: `xcodebuild -scheme NotchClip -configuration Debug build`.
  Fix all warnings that are Swift 6 concurrency errors.

## 4. Architecture

```
NotchClip/
  App/NotchClipApp.swift              // @main, NSApplicationDelegateAdaptor
  App/AppDelegate.swift               // creates panel, starts monitor
  Window/NotchPanel.swift             // NSPanel subclass
  Window/NotchWindowController.swift  // positioning, screen changes, mouse tracking
  Window/NotchGeometry.swift          // notch rect detection per screen
  Views/NotchShape.swift              // animatable Shape (inverse top ears + bottom radius)
  Views/NotchRootView.swift           // state machine: collapsed / hovered / expanded
  Views/ClipboardListView.swift
  Views/ClipboardRowView.swift
  Views/HeaderView.swift
  Views/SettingsView.swift
  Model/ClipItem.swift
  Model/ClipboardStore.swift          // @Observable, persistence, dedupe, limits
  Services/PasteboardMonitor.swift
  Services/LaunchAtLogin.swift        // SMAppService.mainApp
```

## 5. Window behavior (get this exactly right)

- `NSPanel` with `.borderless` and `.nonactivatingPanel` style masks. Set `isOpaque = false`,
  `backgroundColor = .clear`, `hasShadow = false`.
- Window level: `.statusBar` or higher
  (e.g. `NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)`).
  It must sit over the menu bar.
- `collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`.
- Must not steal focus from the frontmost app when hovered. It should become key only when the
  search field needs typing; `canBecomeKey` returns true only in expanded state.
- **Notch detection:** use `NSScreen.safeAreaInsets.top` together with `auxiliaryTopLeftArea` /
  `auxiliaryTopRightArea` to compute the exact notch width, height and x position. If the screen
  has no notch (external display, older Mac), fall back to a fake notch: a 180×32pt black pill
  centered at the top.
- Use the screen with the notch by default (built-in display). Add a setting:
  "Built-in display / Display with mouse".
- Handle `NSApplication.didChangeScreenParametersNotification`: reposition on display
  connect/disconnect, resolution change and lid close.
- The window frame should be the MAX expanded size, anchored top-center. The SwiftUI shape
  animates inside it.
- **Click-through:** the transparent parts of the window must NOT block clicks on the menu bar or
  apps below. Implement this one of two ways:
  - (a) Toggle `ignoresMouseEvents` based on whether the cursor is inside the current visible
    shape rect. Track the cursor with a global + local `NSEvent` mouseMoved monitor and a ~60Hz
    check only while near the top of the screen.
  - (b) Resize the actual window frame to match the state, animated.

  Prefer (a). Document the choice.
- Hover detection must work even when another app is active. Use
  `NSEvent.addGlobalMonitorForEvents` for `.mouseMoved`. Note: global mouse-moved monitoring does
  not require Accessibility permission. Verify this and handle it if it is wrong.
- Collapse when: the user clicks outside (global `.leftMouseDown` monitor), presses Esc, the
  mouse leaves the expanded panel for >400ms, or after copying an item (configurable).

## 6. Clipboard monitoring

- Poll `NSPasteboard.general.changeCount` every 0.4s on a background-safe timer. On change, read
  the contents.
- Supported types, in priority order: file URLs, images (`.tiff`/`.png`), URLs, rich text (keep
  RTF data but display plain text), plain text, colors.
- Store a `ClipItem` with these fields: `id: UUID`, `kind`, `plainText?`, `rtfData?`,
  `imageFileName?`, `fileURLs?`, `sourceAppBundleID?`, `sourceAppName?`, `createdAt`,
  `isPinned`, `contentHash`.
- Get the source app from `NSWorkspace.shared.frontmostApplication` at capture time. Show its icon
  (16pt) on each row.
- **Privacy:** SKIP items whose pasteboard types include `org.nspasteboard.ConcealedType`,
  `org.nspasteboard.TransientType` or `org.nspasteboard.AutoGeneratedType`. These are used by
  password managers. Also add an "Ignored apps" list in settings, defaulting to 1Password,
  Bitwarden, Keychain Access and Passwords.
- **Dedupe:** if the new content hash equals an existing item, move that item to the top instead
  of adding a duplicate.
- Ignore whitespace-only text. Cap text at 1MB and images at 10MB.
- **Self-copies:** when the app writes to the pasteboard, record the resulting changeCount and
  ignore it in the monitor, so it doesn't re-add the item.
- Newer macOS versions may show a privacy prompt when an app reads the pasteboard without user
  interaction. Check the current SDK for `NSPasteboard` access-behavior / detection APIs. If they
  are present, use them, handle the "denied" state gracefully, and show an inline card in the
  panel explaining how to allow access.

## 7. Persistence

- Store data in `~/Library/Application Support/NotchClip/`. Save `history.json` (Codable) and
  write images to an `images/` subfolder as PNG.
- Use atomic writes, debounced 1s after changes. Load on launch.
- History limit setting: 50 / 100 / 200 / 500 (default 100). Pinned items never count toward or
  get evicted by the limit. Delete orphaned image files on eviction.

## 8. Expanded panel UI & interactions

- **Header:** clipboard icon + "Clipboard" label + item count; a search toggle; a pinned-only
  filter; "Clear all" (with inline confirm: the button turns red and says "Confirm" for 3s); a
  gear that opens Settings in a normal window.
- **List:** vertical `ScrollView` with `LazyVStack`, with pinned items in a section at the top.
  Each row is a card containing:
  - The source app icon.
  - A content preview:
    - Text: 2 lines, truncated.
    - Image: 44pt-tall thumbnail plus its dimensions.
    - Files: the file icon, the name, and "+N more" if there are several.
    - Color: a swatch plus the hex value.
    - URL: the host in bold plus the path dimmed.
  - A relative timestamp ("2m").
  - On hover only, trailing buttons: pin and delete (xmark/trash). The hover background brightens
    from white 8% to 12% opacity.
- **Click a row:** write the item back to the pasteboard with all of its original
  representations. Show a "Copied" checkmark morph on that row for 0.9s, then optionally
  collapse.
- **Delete:** the row animates out (opacity + height collapse + slight slide left) using
  `.transition(.asymmetric(...))`. Also support a right-click context menu with Copy, Pin/Unpin,
  Delete, and "Copy as plain text".
- **Keyboard:** when expanded, ↑/↓ move the selection; Return copies; ⌫ deletes; ⌘F focuses
  search; ⌘1…⌘9 quick-copy; Esc collapses.
- **Global hotkey:** ⌥⌘V (configurable) toggles the panel.
- **Empty state:** a centered dimmed clipboard symbol with "Copy something to see it here".
- **Search:** filters text, URL, file names and source app name, case-insensitive, live.

## 9. Animation implementation details

- `NotchShape` must be an animatable `Shape`. Use `animatableData` holding width, height, the
  bottom corner radius and the top ear radius, so a single spring drives a smooth morph between
  collapsed, hovered and expanded. The collapsed shape must match the real notch, so it aligns
  pixel-perfectly when there is no hover.
- Drive the state with an enum `NotchState { case collapsed, hovered, expanded }` and
  `withAnimation`. Use different springs:
  - Hover: response 0.3, damping 0.7.
  - Expand: response 0.42, damping 0.78.
  - Collapse: response 0.35, damping 0.9 (no overshoot).
- Content uses `.transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))` plus a
  blur modifier, delayed ~90ms after the expand starts.
- Add a subtle outer glow in the hovered/expanded state:
  `.shadow(color: .white.opacity(0.08), radius: 12)`.
- Everything must run at 120Hz on ProMotion without dropped frames. Use no `GeometryReader`
  inside list rows. Thumbnails are generated once and cached.
- Respect "Reduce Motion": replace the springs with 0.15s ease fades.

## 10. Settings window

Use a plain SwiftUI `Settings` scene or a small NSWindow. It should include:

- Launch at login (`SMAppService.mainApp`).
- History limit.
- Collapse after copy (on/off).
- Display choice.
- Global hotkey.
- Ignored apps (add from running apps / remove).
- Clear history.
- Quit.

Also offer Quit in the right-click menu of the collapsed notch.

## 11. Milestones (commit after each with git)

1. XcodeGen project builds and launches as an agent app. A black panel is positioned exactly over
   the notch on the built-in display, with a fallback pill on non-notch screens.
2. NotchShape with the collapsed/hover/expand animations, click-through and outside-click
   collapse.
3. PasteboardMonitor and ClipboardStore with persistence, dedupe, privacy filtering and
   self-copy ignoring.
4. Full list UI: rows for all content kinds, copy-back, delete, pin, context menu, empty state.
5. Search, keyboard navigation, global hotkey.
6. Settings, launch at login, multi-display handling, Reduce Motion.
7. Polish pass: compare against the reference GIF's feel, tune the springs, check alignment on a
   notch Mac at multiple scaled resolutions, and write the README with build/run instructions.

## 12. Acceptance criteria (verify each, and list results in a final summary)

- [ ] The collapsed state is visually indistinguishable from the hardware notch.
- [ ] Menu bar items next to the notch remain clickable at all times.
- [ ] Hovering animates smoothly. Clicking expands with a spring. Clicking outside or pressing Esc
      collapses.
- [ ] Copying text, an image, a file in Finder, and a URL in Safari each create the correct row
      type with the source app icon.
- [ ] Copying a password from a password manager does NOT appear.
- [ ] Clicking a row puts it back on the clipboard (verify by pasting in TextEdit), and it is not
      duplicated in history.
- [ ] Delete, pin, clear all and search work. History survives a relaunch.
- [ ] Works in full-screen apps and across Spaces.
- [ ] Unplugging/plugging an external display repositions correctly.
- [ ] No focus stealing: typing in another app continues uninterrupted while hovering the notch.
- [ ] Zero Swift 6 concurrency errors. No crashes when the clipboard has unusual types.

Write unit tests for ClipboardStore (dedupe, limit eviction with pinned items, persistence round
trip) and for the content-type classification logic.

When finished, print a short summary: what was built, any deviations (see DECISIONS.md), and the
exact commands to build and run.