#### Description

Copies text to the clipboard. With `--text`, writes that text directly to the clipboard (no keystroke
sent). Without `--text`, presses `cmd+c` (requires the Accessibility permission) to copy whatever is
currently selected in the focused app, then returns the resulting clipboard contents — so the caller can
confirm what was actually copied.

#### Usage

```bash
aux4 computer mac clipboard copy [--text <text>]
```

--text   Text to put on the clipboard directly; omit to copy the current selection via cmd+c

#### Example

```bash
aux4 computer mac clipboard copy
```

```json
{"text":"the selected text"}
```

```bash
aux4 computer mac clipboard copy --text "hello"
```

```json
{"text":"hello"}
```
