# Decisions

- **Not sandboxed (v1).** No entitlements file, so pasteboard reading and launch-at-login need no extra setup.
- **Ad-hoc signing** (`CODE_SIGN_IDENTITY = "-"`) so it builds from the CLI with no developer account.
- **Generated `.xcodeproj` is git-ignored.** `project.yml` is the source of truth; run `xcodegen` after cloning.
- **Notch width** = `screen.frame.width - auxiliaryTopLeftArea.width - auxiliaryTopRightArea.width`, notch x = left area width. Uses only widths, so it doesn't depend on which coordinate space the auxiliary rects are reported in. Height = `safeAreaInsets.top`.
