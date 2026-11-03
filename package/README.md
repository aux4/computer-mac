# aux4/computer-mac

Computer-use for AI agents on macOS. A native Swift CLI (no Python/Node/cliclick dependency) that lets an
agent see the screen and act on it: take screenshots, read the text on screen (OCR), wait for something to appear, read the accessibility tree, find and click UI
elements, type text, press keyboard shortcuts, use menus, select text, set fields, answer dialogs, scroll,
drag, control the clipboard, and manage apps, files and windows. All commands print JSON to stdout, and
every action is recorded in an action log that a stop switch can halt at once.

It is built to **work alongside the person using the Mac**: actions run in the background by default —
on an app that isn't in front, without moving the mouse cursor or changing the frontmost app — and fall
back to real input only when the background isn't possible. The package includes an AI skill for using it
this way.

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

- **Accessibility** is required for `read`, `find`, `state`, `menu`, `select`, `set`, `dialog`, `click`,
  `move`, `drag`, `type`, `shortcut`, `scroll` and `focus`.
- **Screen Recording** is required for `screenshot` and `ocr` (except `ocr --image`).

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
| `shortcut --app` | Presses the app's enabled menu item for that shortcut, or sends the keys to the app if it's already in front; `cmd+a` selects the focused text via Accessibility | No enabled menu item — e.g. `cmd+z` in a background app |
| `menu --path` | Presses the menu item via Accessibility, without opening the menu | The item is disabled while the app is in the background (Close, Undo, Copy…) |
| `select` | Sets the text selection of the focused (or given) element via Accessibility | The element doesn't take an accessibility selection (`--all` then presses `cmd+a`) |
| `set` | Sets the value / presses the checkbox / picks the option via Accessibility | The app refuses the change while in the background (retried in front) |
| `dialog --press` | Presses the dialog's button via Accessibility | The button can't be pressed in the background (pressed in front) |
| `scroll` | Moves the scroll area's scroll bar via Accessibility (or posts the scroll to the app with `--app`) | No scroll area at the point and no `--app` |
| `open` | Launches / opens a file or URL without activating; leaves an already-running app as it is | — |
| `screenshot --app` | Captures the app's window even when covered | — |
| `ocr --app` | Reads the text in the app's window even when covered | The window isn't on screen (app hidden, window on another Space) |

**Always foreground:** `focus`, `move`, `drag`, and `shortcut` without `--app` (a system-wide hotkey such
as `cmd+space`).

### Coordinates

With `--app`, `--x`/`--y` are **relative to that app's front window** — the same space as a
`screenshot --app` image (divide image pixels by its `scale`) and `find --app`'s `windowCenter`. The
screenshot output includes the window's `frame` in screen points, and `ocr --app` reports a `windowCenter`
for every line of text it reads. Without `--app`, coordinates are screen points.

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
aux4 computer mac screenshot --app "Calculator" --annotate true [--roles actionable|all] [--limit 150]
aux4 computer mac screen
aux4 computer mac cursor
```

`screenshot` captures a display (via `--display`, index from `computer mac screen`) or a specific app's
front window (via `--app`), even when it's covered by other windows. The image is resized down to `--maxWidth` (default `1568`, a sane upper
bound for vision models) preserving aspect ratio, and saved as PNG to `--output` (or a temp file if
omitted).

`--annotate true` turns the screenshot into a set-of-marks image for a vision model: a numbered box on each
actionable element (buttons, links, fields, checkboxes, menus, pop-ups, tabs, rows; `--roles all` adds text,
images and headings), and `marks` in the output tell the model what each number is and how to act on it:

```json
{
  "n": 10,
  "ref": "0.0.0.1.0.6",
  "role": "AXButton",
  "label": "7",
  "frame": {"x": 472, "y": 586, "width": 48, "height": 48},
  "center": {"x": 496, "y": 610},
  "windowCenter": {"x": 34, "y": 211},
  "image": {"x": 10, "y": 187, "width": 48, "height": 48}
}
```

Act on a mark by its `ref` (`click --element 0.0.0.1.0.6 --app Calculator`) or its `windowCenter`; `image` is the
box in the PNG's pixels. Elements scrolled out of view are left out; past `--limit` marks the output says
`truncated`. Without `--app`, the frontmost app's windows are annotated.

### Three ways to look at an app

| Command | What it asks | Good for |
|---------|--------------|----------|
| `read` / `find` | The app itself, through Accessibility: the elements it exposes, with roles, labels, values and frames | Exact labels and values, clicking by `ref`; fast and precise when the app exposes its UI |
| `screenshot` | The pixels: an image of the screen or a window | Giving a vision model the full picture: layout, icons, colors, anything drawn |
| `ocr` | The pixels, read as text: each line with its position in click coordinates | Text the accessibility tree doesn't expose (canvas UIs, images, remote desktops), and checking what is actually shown |

All three work on a covered window with `--app`, and their positions line up: a `find --app` match's
`windowCenter`, an `ocr --app` match's `windowCenter`, and a point in a `screenshot --app` image (divided by
its `scale`) can all be passed to `click --app --x --y`.

### Reading text from pixels

```bash
aux4 computer mac ocr [--app "Calculator"] [--image file.png] [--text "1,792"] [--level accurate|fast] [--languages en-US,pt-BR] [--timeout 60s]
```

`ocr` recognizes text on this Mac (no network, nothing to download) in the main display, in an app's
front window (`--app`, even when covered), or in an existing PNG (`--image`, no Screen Recording needed).
Each line of text is an entry in `matches` (the same key as `find`) with `text`, `confidence` (`0`–`1`),
a `frame` and a `center` in screen points, plus a `windowCenter` with `--app`. `--text` keeps only the
lines containing that text (ignoring case, whitespace and commas, so `1792` matches `1,792`; no match is an empty `matches` array,
not an error) and adds a `match` with the position of just that text.

```bash
aux4 computer mac ocr --app Calculator --text "1,792"
```

```json
{"app":"Calculator","height":408,"level":"accurate","matches":[{"center":{"x":645,"y":511.5},"confidence":1,"frame":{"height":33,"width":74,"x":608,"y":495},"match":{"center":{"x":645,"y":511.5},"frame":{"height":33,"width":74,"x":608,"y":495},"windowCenter":{"x":183,"y":112.5}},"text":"1,792","windowCenter":{"x":183,"y":112.5}}],"mode":"background","scale":2,"source":"window","text":"1,792","width":230,"window":{"frame":{"height":408,"width":230,"x":462,"y":399},"id":331,"title":"Calculator"}}
```

**Note:** very small or low-contrast text can be missed or misread, and `--level fast` is much weaker
than the default `accurate` (on light-on-dark UIs it may find nothing). Check `confidence`, and prefer
`find` when the app exposes the element.

`ocr` never runs past `--timeout` (default `60s`): it exits `1` with a JSON error on stderr, e.g.
`{"error":"Text recognition did not finish within 60s","phase":"recognition",...}`, and puts back the
frontmost app if it had brought one forward. A screen capture that doesn't respond within 10s fails
with `{"error":"Screen capture did not respond within 10s","phase":"capture"}`.

**Note:** on a Mac with a Neural Engine, the first recognition after installing or updating the package
takes about 30s while macOS prepares its text models; after that each call takes a fraction of a
second. It takes longer while macOS's Neural Engine compiler is busy with other requests. If a call
times out during that preparation, the error says so (`note`), and the preparation finishes in the
background (`"warmup":true`) so the next call is fast.

### Waiting for something to appear

```bash
aux4 computer mac wait [--text "1792"] [--role AXButton] [--app "Calculator"] [--gone true] [--source auto|ax|ocr] [--timeout 10s] [--interval 500ms]
```

`wait` blocks until text or an element appears — checking the app's accessibility tree first, then
its window's pixels with OCR when the tree has no match — or, with `--app` alone, until the app has an
on-screen window. `--gone true` waits until it's no longer there. It returns as soon as the condition
holds, with how long it `waited`, the `source` that saw it (`ax`, `ocr` or `app`) and the same `matches`
as `find`/`ocr`/`windows`, ready for `click`. Text matching ignores case, whitespace and commas, so
`1792` matches `1,792`.

```bash
aux4 computer mac wait --app Calculator --text 1792
```

```json
{"app":"Calculator","matches":[{"center":{"x":645,"y":511},"label":"Edit field","ref":"0.0.0.0.1.0.0.0.0.0","role":"AXStaticText","value":"1,792","windowCenter":{"x":183,"y":112}}],"source":"ax","waited":1.7}
```

On timeout (`--timeout` takes `500ms`, `10s`, `2m`; default `10s`) it exits `1` with a JSON error on stderr
naming the condition and what it saw on the last check (the first texts from accessibility and OCR,
and whether the app was running with a window), so an agent can tell a wrong guess from a slow app.
It always stops at `--timeout`, even when an app stops answering or a screen capture stalls. `wait`
only reads: it never moves the cursor or brings an app forward.

### One call to see where things stand

```bash
aux4 computer mac state [--app "TextEdit"] [--depth 3] [--limit 120]
```

`state` returns the frontmost app, the target app (`pid`, `bundleId`, `hidden`), its windows (`title`,
`frame`, `main`/`focused`/`minimized`), the focused element (shaped like a `find` match), the open dialog if
any, and a compact tree of the window's actionable and text elements — each with a `ref` to act on. Layout
groups are skipped, `--depth` counts levels of meaningful elements, and the list is capped (`truncated` and
a `note` say when there's more). Small enough to hand to an agent on every step.

```json
{"app":{"bundleId":"com.apple.calculator","frontmost":false,"hidden":false,"name":"Calculator","pid":62830},"dialog":null,"elements":[{"frame":{"height":36,"width":73,"x":609,"y":488},"label":"Edit field","ref":"0.0.0.1.0.1.0","role":"AXStaticText","value":"1,792"},{"frame":{"height":48,"width":48,"x":526,"y":532},"label":"All Clear","ref":"0.0.0.1.0.3","role":"AXButton"}],"frontmost":{"bundleId":"com.anthropic.claudefordesktop","name":"Claude","pid":49456},"windows":[{"frame":{"height":408,"width":230,"x":462,"y":399},"main":true,"ref":"0","title":"Calculator"}]}
```

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

### Menus, selections, fields and dialogs

```bash
aux4 computer mac menu [--app "TextEdit"] [--depth 2]
aux4 computer mac menu --app "TextEdit" --path "Format > Font > Bold"
aux4 computer mac select --app "TextEdit" --all true
aux4 computer mac select --app "TextEdit" --text "aux4" [--occurrence 2]
aux4 computer mac select --app "TextEdit" --start 0 --length 5 [--element 0.0.0]
aux4 computer mac set --app "TextEdit" --element 0.0.0 --value "new text"
aux4 computer mac set --app "System Settings" --element 0.1.3 --checked true
aux4 computer mac set --app "TextEdit" --element 0.2.4 --option "Helvetica"
aux4 computer mac dialog [--app "TextEdit"]
aux4 computer mac dialog --app "TextEdit" --press "Don't Save"
```

- `menu` lists the menu bar as a tree (`title`, `ref`, `checked`, `shortcut`, `enabled`, `children`), or
  presses an item by path. Titles match case-insensitively and a trailing `…` is optional; when one doesn't
  match, the error lists what's available at that level.
- `select` selects text in the app's focused element (or `--element`) and returns the `selected` text and
  its `range`; `clipboard copy --app` then copies it, both in the background.
- `set` sets a text field / text area / slider value, a checkbox state or a pop-up / combo box / radio group
  option, and returns the value `before` and `after`. With `--value` on a document window, see the silent
  data-loss note above.
- `dialog` reports the open alert, sheet, dialog or save/open panel — `kind`, `title`, `text`, `buttons`
  (with `default`/`cancel` flags) and `fields` — or `null`; `--press` presses a button by title and says
  whether the dialog `closed`.

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
aux4 computer mac open com.apple.TextEdit --hidden true
aux4 computer mac open --file ~/notes.txt [--app "TextEdit"] [--wait 10s]
aux4 computer mac open --url https://aux4.io
aux4 computer mac focus "TextEdit"
aux4 computer mac window list "TextEdit"
aux4 computer mac window move --app "TextEdit" [--title notes | --index 0] --x 200 --y 150
aux4 computer mac window resize --app "TextEdit" --width 800 [--height 600]
aux4 computer mac window minimize|restore|close|raise --app "TextEdit" [--title notes]
aux4 computer mac window fullscreen true|false --app "TextEdit"
aux4 computer mac hide "TextEdit"
aux4 computer mac unhide "TextEdit"
aux4 computer mac quit "TextEdit" [--force true] [--timeout 5s]
```

`open` launches an app, or opens a file or URL (in `--app` or the default app), without bringing it to the
front (`--mode foreground` to bring it forward). `--wait` returns once the app shows a window — the file's
window with `--file` — including its `frame`; `--hidden true` launches it hidden. `focus` always brings an
app to the front.

`window` acts on one of an app's windows (`--title`, `--index` from `window list`, or its main window)
through Accessibility, in the background: move, resize, minimize, restore, close (pressing the close button;
a "save changes?" sheet is reported as `dialog`), enter or leave full screen. Each returns the window `before`
and `after`. `window raise` brings the app to the front, so it's always foreground. `window list` includes
hidden and minimized windows, which `windows` (on-screen windows of every app) leaves out.

`hide`/`unhide` hide an app or show it again without bringing it to the front. `quit` asks an app to quit
without activating it and waits for it to exit; an app with unsaved changes may answer with a sheet, which
`quit` returns as `dialog` (`terminated: false`) for you to answer with `dialog --press`. `--force true`
kills it (unsaved changes are lost); force-quitting Finder and quitting the Dock, loginwindow and other session
processes are refused.

**Note:** text written through Accessibility (`set --value`, or `type`/`clipboard paste` in the background) doesn't
mark a document as edited, so closing or quitting may discard it without asking. When this applies, the command's
output adds `"documentEdited": false` and a `"warning"` telling you to save explicitly
(`shortcut cmd+s --app <name>` or `menu --path "File > Save"`) or to use `--mode foreground` for real keystrokes.

Wherever `--app` is accepted, the app can be given by name or by bundle id (`com.apple.TextEdit`).

## Action log and stop switch

```bash
aux4 computer mac log [--limit 20]
aux4 computer mac stop
aux4 computer mac resume
```

Every command that sends input or changes state (`click`, `type`, `shortcut`, `scroll`, `drag`, `move`,
`set`, `select`, `menu --path`, `dialog --press`, `clipboard copy`/`paste`, `open`, `focus`, `window`
(except `list`), `quit`, `hide`, `unhide`) appends one
JSON line to `~/Library/Logs/aux4-computer-mac/actions.jsonl` — time, command, app, arguments, mode and
result or error — including attempts that failed or were refused. Typed text is cut to a short prefix plus
its length. The file is rotated at 10MB. `log` prints the most recent entries.

`stop` turns on the stop switch (a `STOP` file in `~/Library/Application Support/aux4-computer-mac`): every
input or state command then refuses with a clear JSON error until `resume`, while read-only commands
(`state`, `read`, `find`, `screenshot`, `ocr`, `wait`, listing menus or dialogs) keep working. Setting
`AUX4_COMPUTER_MAC_STOP=1` in an agent's environment stops it the same way.

```json
{"command":"click","error":"Stopped: aux4 computer mac is not sending input or changing state (/Users/sally/Library/Application Support/aux4-computer-mac/STOP exists). Run 'aux4 computer mac resume' to allow it again.","stopped":true}
```

### Example: work in TextEdit without interrupting the user

```bash
aux4 computer mac open --file ~/notes.txt --app "TextEdit" --wait 10s
aux4 computer mac state --app "TextEdit"
aux4 computer mac select --app "TextEdit" --all true
aux4 computer mac clipboard copy --app "TextEdit"
aux4 computer mac menu --app "TextEdit" --path "Format > Make Plain Text"
aux4 computer mac dialog --app "TextEdit" --press "OK"
aux4 computer mac type "hello from an agent" --app "TextEdit"
aux4 computer mac clipboard paste --text " and a pasted line" --app "TextEdit"
aux4 computer mac screenshot --app "TextEdit"
aux4 computer mac ocr --app "TextEdit" --text "hello from an agent"
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

## AI skill

```bash
aux4 ai skill computer-mac prompt
```

The methodology tells agents to start from `state`, find elements with `find` (and `ocr` when the text isn't in the
accessibility tree), look with `screenshot --annotate` when they need to see the layout, act by element ref, menu
path, `set` and `select` rather than coordinates and keystrokes, and `wait` for the result instead of sleeping; what
works in the background and when the foreground fallback happens; the coordinate rules; the stop switch and action
log; permissions; and troubleshooting.

## Output and errors

Every command prints a single JSON object to stdout. On failure (bad arguments, missing permission,
element not found, app not running) it prints `{"error": "..."}` and exits non-zero — agents should check
the exit code or the presence of an `error` key rather than parsing stdout as always-successful.

## Troubleshooting

### `ocr` (or OCR in `wait`) is slow or times out

On a Mac with a Neural Engine, macOS prepares its text-recognition model the first time a new install
of this package recognizes text (also after a macOS update or restart): that first call takes about
30s, then every call takes a fraction of a second. `ocr`'s default `--timeout` of `60s` covers it.
With a short deadline (for example `wait --timeout 5s`), OCR may not contribute on that first cold
call; the accessibility tree is still checked, and the error's `note`/`notes` says the model was still
being prepared. The preparation then finishes in the background (`"warmup":true`), so retry shortly.

If **every** call takes ~30s or longer, macOS's Neural Engine compiler is stuck or backed up: check
whether `ANECompilerService` sits at ~100% CPU (Activity Monitor or `ps -axo pcpu,comm | grep ANECompiler`),
stop any leftover `aux4-computer-mac` processes, and run `sudo killall ANECompilerService` (or restart
the Mac). Recognition is back to ~0.1–0.3s afterwards.
