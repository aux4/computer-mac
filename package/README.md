# aux4/computer-mac

Computer-use for AI agents on macOS. A native Swift CLI (no Python/Node/cliclick dependency) that lets an
agent see the screen and act on it: take screenshots, read the accessibility tree, find and click UI
elements, type text, press keyboard shortcuts, scroll, drag, control the clipboard, and manage apps and
windows. All commands print JSON to stdout. Coordinates are in screen points.

This package is **darwin-only** (macOS). It ships native binaries for `darwin/arm64` and `darwin/amd64`.

## Installation

```bash
aux4 aux4 pkger install aux4/computer-mac
```

## Permissions

Before anything else, check what this Mac has granted to the terminal/app running aux4:

```bash
aux4 computer mac permissions
```

```json
{
  "accessibility": { "granted": false, "guidance": "Open System Settings > Privacy & Security > Accessibility and enable this terminal/app. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\"" },
  "screenRecording": { "granted": false, "guidance": "Open System Settings > Privacy & Security > Screen Recording and enable this terminal/app. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture\"" }
}
```

- **Accessibility** is required for `read`, `find`, `click`, `move`, `drag`, `type`, `shortcut`, `scroll`
  and `focus`.
- **Screen Recording** is required for `screenshot`.

Every command that needs a permission that isn't granted returns a clear JSON error with the exact System
Settings pane to open — never a silent no-op.

## Commands

### Seeing the screen

```bash
aux4 computer mac screenshot [--output file.png] [--display 0] [--app "Safari"] [--maxWidth 1568]
aux4 computer mac screen
aux4 computer mac cursor
```

`screenshot` captures a display (via `--display`, index from `computer mac screen`) or a specific app's
frontmost window (via `--app`). The image is resized down to `--maxWidth` (default `1568`, a sane upper
bound for vision models) preserving aspect ratio, and saved as PNG to `--output` (or a temp file if
omitted).

### Reading the UI

```bash
aux4 computer mac read [--app "TextEdit"] [--depth 10]
aux4 computer mac find "Save" [--role AXButton] [--app "TextEdit"]
```

`read` walks the accessibility tree of the frontmost app (or `--app`) and returns a flat list of elements
with a `ref`, `role`, `label`, `value`, `frame` and `enabled`/`focused` state. `find` filters that same
tree by text and/or role and includes a `center` point for each match. A `ref` is only valid against the
current state of that app — read/find again if the UI has changed.

### Acting on the UI

```bash
aux4 computer mac click [--x 100 --y 200] [--button left|right] [--count 2]
aux4 computer mac click --element 0.2.1 [--app "TextEdit"]
aux4 computer mac move --x 100 --y 200
aux4 computer mac drag --x 100 --y 200 --toX 400 --toY 200
aux4 computer mac scroll [--x 100 --y 200] --dx 0 --dy -200
```

Clicking by `--element` (a `ref` from `read`/`find`) performs an accessibility press action directly on
that element, which is more reliable than simulating a coordinate click. Clicking by `--x`/`--y` posts a
real mouse event at that location.

### Keyboard

```bash
aux4 computer mac type "Hello, world!" [--delay 300]
aux4 computer mac shortcut "cmd+shift+4"
aux4 computer mac shortcut "cmd+a"
aux4 computer mac shortcut "enter"
```

`type` sends unicode-safe keystrokes for arbitrary text. `shortcut` parses a combo like `cmd+shift+4` —
modifiers (`cmd`/`command`, `shift`, `alt`/`option`, `ctrl`/`control`, `fn`) plus one key — and posts it as
a real key event. Both accept an optional `--delay` (milliseconds) to wait before acting, useful right
after opening a panel like Spotlight.

### Clipboard

```bash
aux4 computer mac clipboard copy [--text "..."]
aux4 computer mac clipboard paste [--text "..."]
aux4 computer mac clipboard read
```

- `copy` — with `--text`, writes that text to the clipboard directly; without, presses `cmd+c` to copy
  the current selection and returns what was actually copied.
- `paste` — with `--text`, writes that text to the clipboard first, then presses `cmd+v` to paste it into
  the focused app; without, pastes whatever is already on the clipboard.
- `read` — returns the current clipboard text with no side effects.

Text only, for now.

### Apps and windows

```bash
aux4 computer mac apps
aux4 computer mac windows
aux4 computer mac open "TextEdit"
aux4 computer mac focus "TextEdit"
```

### Example: open Spotlight, launch an app, type and paste

```bash
aux4 computer mac shortcut "cmd+space"
aux4 computer mac type "TextEdit" --delay 300
aux4 computer mac shortcut "enter" --delay 200
aux4 computer mac type "hello from an agent" --delay 800
aux4 computer mac shortcut "cmd+a"
aux4 computer mac clipboard copy
aux4 computer mac clipboard read
aux4 computer mac clipboard paste --text "replaced via agent"
```

## Output and errors

Every command prints a single JSON object to stdout. On failure (bad arguments, missing permission,
element not found, app not running) it prints `{"error": "..."}` and exits non-zero — agents should check
the exit code or the presence of an `error` key rather than parsing stdout as always-successful.
