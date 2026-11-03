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

**Silent data loss:** when the paste lands via Accessibility (`"method":"accessibility"`) inside a
document window (one with an `AXDocument`, i.e. backed by a file), macOS does not mark that window edited
— only real keystrokes or a menu action do. The title bar shows no unsaved-changes indicator, and closing
the window discards the pasted text with no "do you want to save?" prompt. In that case the output adds
`"documentEdited": false` and a `"warning"` telling you to save explicitly
(`shortcut cmd+s --app <app>` or `menu --path "File > Save" --app <app>`), or to re-run with
`--mode foreground` for a real `cmd+v`. This doesn't apply when the Paste menu item was pressed instead.

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
