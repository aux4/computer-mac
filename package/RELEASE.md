# Release Notes

## 0.2.0

### Background mode by default

Actions now run in the background by default, so an agent can work in an app while the person keeps
using the Mac: the mouse cursor doesn't move and the frontmost app doesn't change.

- New `--mode auto|background|foreground` on `click`, `type`, `shortcut`, `scroll`, `open`,
  `clipboard copy` and `clipboard paste` (default `auto`: background, falling back to real input only
  when the background isn't possible; `background` errors instead of falling back; `foreground` is the
  previous behavior).
- Every action's JSON output has `"mode":"background"` or `"mode":"foreground"`, plus `fallbackReason`
  and `restored` when `auto` fell back. After a fallback the cursor position and the previously frontmost
  app are restored.
- New `--app` on `type`, `shortcut`, `scroll`, `clipboard copy` and `clipboard paste`.
- `click` presses the target app's accessibility element at the point, even when its window is covered.
- `type` and `clipboard paste` insert text at the app's text cursor; `clipboard copy` reads its selection.
- `shortcut --app` presses the app's matching menu item; without `--app` it stays a system-wide shortcut.
- `scroll` moves the scroll area's scroll bar.
- `open` launches without activating the app and leaves an already-running app untouched.
- `focus`, `move` and `drag` are always foreground and say so.

### Coordinates with `--app`

With `--app`, `--x`/`--y` on `click` and `scroll` are relative to the app's front window — the same space
as `screenshot --app`. `screenshot --app` output now includes the window `frame`, and `find --app` adds a
`windowCenter` to each match. **Breaking:** before, `--app` on `click` only applied to `--element` and `--x`/`--y` were always screen points.

### Build

- Built, tested and published by GitHub Actions (`aux4/action@v1`) on a macOS runner;
  publishing is gated on `aux4 test run` passing.

### Fixes

- `screenshot --app` no longer crashes (exit 134, `CGS_REQUIRE_INIT` assertion); it captures the app's
  front window even when it's covered.
- The clipboard tests save and restore the clipboard, so running them doesn't overwrite what the user
  copied.

## 0.1.1

### Fixes

- `shortcut` now presses modifier keys as real key events, so system-wide hotkeys like
  `cmd+space` (Spotlight) work. Before, the modifiers were only attached to the key and
  macOS ignored the combo.
- Tests no longer depend on whether this Mac has granted Accessibility or Screen
  Recording: the missing-permission tests set `AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1`,
  and never send real input to the screen.
