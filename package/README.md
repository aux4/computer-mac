# aux4/computer-mac

Computer-use for AI agents on macOS. A native Swift CLI (no Python/Node/cliclick dependency) that lets an
agent see the screen and act on it: take screenshots, read the accessibility tree, find and click UI
elements, type text, press keyboard shortcuts, scroll, drag, control the clipboard, and manage apps and
windows. All commands print JSON to stdout.

It is built to **work alongside the person using the Mac**: actions run in the background by default —
on an app that isn't in front, without moving the mouse cursor or changing the frontmost app — and fall
back to real input only when the background isn't possible.

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

## Background mode (default)

Every action takes `--mode`:

| Mode | Behavior |
|------|----------|
| `auto` (default) | Act in the background; if that isn't possible, fall back to real input, then restore the cursor position and the previously frontmost app |
| `background` | Act in the background only; error instead of falling back |
| `foreground` | Always use real mouse/keyboard input |

Every action's JSON says what happened: `"mode":"background"` or `"mode":"foreground"`, plus a
`fallbackReason` (and what was `restored`) when `auto` fell back.

Pass `--app <name>` to target an app that isn't in front; without it, the frontmost app is the target.

| Command | In the background | Falls back to real input when |
|---------|-------------------|-------------------------------|
| `click --x --y` / `--element` | Presses the app's accessibility element at that point (even if its window is covered); a text field/area gets the focus | Nothing pressable at the point; `--count 2` (double-click) |
| `type` | Inserts the text at the app's text cursor via Accessibility | The focused element doesn't accept text that way |
| `clipboard copy` | Reads the app's selected text and puts it on the clipboard | The app doesn't expose its selection or an enabled Copy menu item |
| `clipboard paste` | Inserts the clipboard text at the app's text cursor | The focused element doesn't accept text that way |
| `shortcut --app` | Presses the app's enabled menu item for that shortcut, or sends the keys to the app if it's already in front | No enabled menu item — e.g. `cmd+a`/`cmd+z` in a background app |
| `scroll` | Moves the scroll area's scroll bar via Accessibility (or posts the scroll to the app with `--app`) | No scroll area at the point and no `--app` |
| `open` | Launches without activating; leaves an already-running app as it is | — |
| `screenshot --app` | Captures the app's window even when covered | — |

**Always foreground:** `focus`, `move`, `drag`, and `shortcut` without `--app` (a system-wide hotkey such
as `cmd+space`).

### Coordinates

With `--app`, `--x`/`--y` are **relative to that app's front window** — the same space as a
`screenshot --app` image (divide image pixels by its `scale`) and `find --app`'s `windowCenter`. The
screenshot output includes the window's `frame` in screen points. Without `--app`, coordinates are screen
points.

```bash
aux4 computer mac screenshot --app Calculator --output /tmp/calc.png
aux4 computer mac click --app Calculator --x 34 --y 211
```

```json
{"action":"AXPress","app":"Calculator","button":"left","count":1,"element":{"label":"7","role":"AXButton"},"mode":"background","screen":{"x":496,"y":610},"x":34,"y":211}
```

## Commands

### Seeing the screen

```bash
aux4 computer mac screenshot [--output file.png] [--display 0] [--app "Safari"] [--maxWidth 1568]
aux4 computer mac screen
aux4 computer mac cursor
```

`screenshot` captures a display (via `--display`, index from `computer mac screen`) or a specific app's
front window (via `--app`), even when it's covered by other windows. The image is resized down to `--maxWidth` (default `1568`, a sane upper
bound for vision models) preserving aspect ratio, and saved as PNG to `--output` (or a temp file if
omitted).

### Reading the UI

```bash
aux4 computer mac read [--app "TextEdit"] [--depth 10]
aux4 computer mac find "Save" [--role AXButton] [--app "TextEdit"]
```

`read` walks the accessibility tree of the frontmost app (or `--app`) and returns a flat list of elements
with a `ref`, `role`, `label`, `value`, `frame` and `enabled`/`focused` state. `find` filters that same
tree by text and/or role and includes a `center` point (screen points) for each match, plus a
`windowCenter` (relative to the app's window) with `--app`. A `ref` is only valid against the
current state of that app — read/find again if the UI has changed.

### Acting on the UI

```bash
aux4 computer mac click --x 100 --y 200 [--app "Calculator"] [--button left|right] [--count 2] [--mode auto]
aux4 computer mac click --element 0.2.1 [--app "TextEdit"]
aux4 computer mac scroll [--x 100 --y 200] --dy=-200 [--app "TextEdit"]
aux4 computer mac move --x 100 --y 200
aux4 computer mac drag --x 100 --y 200 --toX 400 --toY 200
```

Clicking by `--element` (a `ref` from `read`/`find`) presses that element directly. Clicking by
`--x`/`--y` presses whatever element is at that point, in the background; see the table above for when it
falls back to a real mouse click. Pass negative scroll deltas with `=` (`--dy=-200`).

### Keyboard

```bash
aux4 computer mac type "Hello, world!" [--app "TextEdit"] [--delay 300]
aux4 computer mac shortcut "cmd+1" --app "Calculator"
aux4 computer mac shortcut "cmd+shift+4"
aux4 computer mac shortcut "enter"
```

`type` inserts unicode-safe text (emoji and non-ASCII included) into the app's focused element. `shortcut` parses a combo like `cmd+shift+4` —
modifiers (`cmd`/`command`, `shift`, `alt`/`option`, `ctrl`/`control`, `fn`) plus one key — and posts it as
a real key event — or, with `--app`, runs it in that app in the background when it can. Both accept an optional `--delay` (milliseconds) to wait before acting, useful right
after opening a panel like Spotlight.

### Clipboard

```bash
aux4 computer mac clipboard copy [--text "..."] [--app "TextEdit"]
aux4 computer mac clipboard paste [--text "..."] [--app "TextEdit"]
aux4 computer mac clipboard read
```

- `copy` — with `--text`, writes that text to the clipboard directly; without, copies the app's current
  selection (in the background when possible) and returns what was actually copied.
- `paste` — with `--text`, writes that text to the clipboard first, then pastes it into the app's focused
  element (in the background when possible); without, pastes whatever is already on the clipboard.
- `read` — returns the current clipboard text with no side effects.

Text only, for now.

### Apps and windows

```bash
aux4 computer mac apps
aux4 computer mac windows
aux4 computer mac open "TextEdit"
aux4 computer mac focus "TextEdit"
```

`open` launches an app without bringing it to the front (`--mode foreground` to bring it forward);
`focus` always brings it to the front.

### Example: work in TextEdit without interrupting the user

```bash
aux4 computer mac open "TextEdit"
aux4 computer mac type "hello from an agent" --app "TextEdit"
aux4 computer mac clipboard paste --text " and a pasted line" --app "TextEdit"
aux4 computer mac screenshot --app "TextEdit"
```

### Example: open Spotlight, launch an app, type and paste (foreground)

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
