#### Description

Pastes the clipboard into whatever is focused, via `cmd+v` (requires the Accessibility permission). With
`--text`, writes that text to the clipboard first, then pastes it — a one-shot "type this via paste"
primitive. Without `--text`, pastes whatever is already on the clipboard.

#### Usage

```bash
aux4 computer mac clipboard paste [--text <text>]
```

--text   Text to put on the clipboard before pasting; omit to paste the current clipboard contents

#### Example

```bash
aux4 computer mac clipboard paste --text "pasted via agent"
```

```json
{"pasted":"pasted via agent"}
```
