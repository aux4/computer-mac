#### Description

Copies text to the clipboard. With `--text`, writes that text directly to the clipboard (no permission
needed, nothing pressed). Without `--text`, copies the current selection of the target app (`--app`, or
the frontmost app) and returns it, so the caller can confirm what was copied. Requires the Accessibility
permission in that case.

By default (`--mode auto`) copying the selection happens **in the background**: the selected text is read
through Accessibility and written to the clipboard (an empty selection leaves the clipboard untouched and
returns `""`). If the app doesn't expose its selection, its enabled Copy menu item is pressed. If neither
works, `auto` falls back to a real `cmd+c` (the app is brought forward, then the previously frontmost app
and cursor are restored). `--mode background` errors instead of falling back; `--mode foreground` always
presses `cmd+c`.

#### Usage

```bash
aux4 computer mac clipboard copy [--text <text>] [--app <name>] [--mode auto|background|foreground]
```

--text   Text to put on the clipboard directly; omit to copy the current selection
--app    App whose selection to copy (default: the frontmost app)
--mode   `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac clipboard copy --app TextEdit
```

```json
{"app":"TextEdit","method":"accessibility","mode":"background","text":"the selected text"}
```

```bash
aux4 computer mac clipboard copy --text "hello"
```

```json
{"text":"hello"}
```
