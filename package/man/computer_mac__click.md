#### Description

Clicks the UI, in one of two ways. Requires the Accessibility permission.

- `--element <ref>` (from `read`/`find`) performs an AX press action directly on that element — the most
  reliable way to click, since it doesn't depend on the element still being at the same screen location.
  Pass `--app` too if the element isn't in the frontmost app.
- `--x`/`--y` posts a real mouse click at that screen point. `--button` selects `left` (default) or
  `right`; `--count` sets the click count (`2` for a double-click).

#### Usage

```bash
aux4 computer mac click --x <x> --y <y> [--button left|right] [--count <n>]
aux4 computer mac click --element <ref> [--app <name>]
```

--x         X coordinate in screen points
--y         Y coordinate in screen points
--button    `left` or `right` (default: `left`)
--count     Click count, e.g. `2` for a double-click (default: `1`)
--element   Element ref from `read`/`find` to press instead of x/y
--app       App the element ref belongs to (default: the frontmost app)

#### Example

```bash
aux4 computer mac click --x 240 --y 612
```

```json
{"x":240,"y":612,"button":"left","count":1}
```
