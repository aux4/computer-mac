#### Description

Walks the accessibility tree of the frontmost application (or `--app`, matched by a case-insensitive
substring of its name) and returns a flat list of elements. Requires the Accessibility permission.

Each element has:

- `ref` — a path (e.g. `0.2.1`) identifying its position in the tree, valid against the current state of
  that app. Pass it to `computer mac click --element`.
- `role` — the AX role (e.g. `AXButton`, `AXTextField`).
- `label` — title/description, when available. If an element has neither, falls back to its
  `AXTitleUIElement` pointer, then the nearest static text to its left on the same row, then the nearest
  one directly above (e.g. NSSavePanel's unlabelled name field reports `label: "Save As:"`).
- `value` — the AX value as a string, when available (e.g. text field contents).
- `frame` — `{x, y, width, height}` in screen points.
- `enabled` / `focused` — booleans.

`--depth` bounds how deep the tree walk goes (default `10`); increase it for deeply nested UIs, decrease
it for a faster, shallower read.

#### Usage

```bash
aux4 computer mac read [--app <name>] [--depth <n>]
```

--app     App to read (default: the frontmost app)
--depth   Maximum tree depth to walk (default: `10`)

#### Example

```bash
aux4 computer mac read --app "TextEdit"
```

```json
{"app":"TextEdit","elements":[{"ref":"","role":"AXApplication","label":"","value":"","frame":{},"enabled":true,"focused":false}]}
```
