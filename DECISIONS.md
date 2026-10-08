# Decisions

- **Not sandboxed (v1).** No entitlements file, so pasteboard reading and launch-at-login need no extra setup.
- **Ad-hoc signing** (`CODE_SIGN_IDENTITY = "-"`) so it builds from the CLI with no developer account.
- **Generated `.xcodeproj` is git-ignored.** `project.yml` is the source of truth; run `xcodegen` after cloning.
- **Notch width** = `screen.frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width`, notch x = left area width. Uses only widths, so it doesn't depend on which coordinate space the auxiliary rects are reported in. Height = `safeAreaInsets.top`.
- **Click-through: option (a), toggle `ignoresMouseEvents`.** The window is always the max size; `ignoresMouseEvents` is true unless the cursor is inside the current visible shape. Driven purely by global + local `mouseMoved`/`leftMouseDragged` monitors — no 60Hz timer, since the global monitor already fires for every move outside our window and that's the only place a state change can come from.
- **Global mouse monitor needs no Accessibility permission** — verified on macOS 27: hover tracking worked with no prompt.
- **Hover hysteresis:** enter via the notch rect, leave via the (larger) current-state rect, so the hover edge doesn't flicker.
- **Collapsed shape:** square top (ear radius 0) and a 10pt bottom radius, slightly rounder than the hardware cutout. Only pixels outside the cutout are visible, so erring inside it is invisible; erring outside would show black corners.
- **Content/collapse sequencing** uses delayed animations (`.delay(0.09)` on content-in, `.delay(0.12)` on the collapse spring) instead of timers, so rapid toggling never races.
- **Esc** is handled by a local keyDown monitor; the panel becomes key (without activating the app) only while expanded.
- **Wings** (side indicators on the collapsed notch) skipped for now; optional in the spec.
