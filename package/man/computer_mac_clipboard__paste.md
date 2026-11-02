#### Description

Pastes the clipboard text into the focused element of the target app (`--app`, or the frontmost app).
With `--text`, writes that text to the clipboard first, then pastes it — a one-shot "type this via paste"
primitive. Without `--text`, pastes whatever is already on the clipboard. Requires the Accessibility
permission.

By default (`--mode auto`) the paste happens **in the background**: the clipboard text is inserted at the
app's text cursor through Accessibility (or the app's enabled Paste menu item is pressed), without moving
the cursor or bringing the app forward. If that isn't possible, `auto` falls back to a real `cmd+v` (the
app is brought forward, then the previously frontmost app and cursor are restored). `--mode background`
errors instead of falling back; `--mode foreground` always presses `cmd+v`.

#### Usage

```bash
aux4 computer mac clipboard paste [--text <text>] [--app <name>] [--mode auto|background|foreground]
```

--text   Text to put on the clipboard before pasting; omit to paste the current clipboard contents
--app    App to paste into (default: the frontmost app)
--mode   `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac clipboard paste --text "pasted via agent" --app TextEdit
```

```json
{"app":"TextEdit","method":"accessibility","mode":"background","pasted":"pasted via agent"}
```
