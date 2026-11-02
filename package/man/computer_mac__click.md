#### Description

Clicks the UI. By default (`--mode auto`) the click happens **in the background**: the target app's
accessibility element is pressed directly, so the mouse cursor doesn't move and the frontmost app doesn't
change — the person using the Mac isn't interrupted. Requires the Accessibility permission.

- `--x`/`--y` — the point to click. **With `--app`, coordinates are relative to that app's front window**,
  the same coordinate space as `screenshot --app` images (divide image pixels by the screenshot's `scale`)
  and `find --app`'s `windowCenter`. Without `--app`, they are screen points and target the frontmost app.
- `--element <ref>` (from `read`/`find`) presses that element directly. Pass `--app` too if the element
  isn't in the frontmost app.
- `--button` selects `left` (default, presses the element) or `right` (opens the element's context menu).
- `--count 2` (double-click) has no accessibility equivalent, so it always uses real input.

How the background click works: the element at the point is found in the app's own accessibility tree
(even when its window is covered by other windows); the nearest element with a press action is pressed.
Clicking a text field or text area moves the keyboard focus into it.

Modes:

- `auto` (default) — background; if it isn't possible (nothing pressable at that point, a double-click),
  falls back to a real mouse click: the app is brought forward, the click is posted, and then the cursor
  position and the previously frontmost app are restored. The output says `"mode":"foreground"` with a
  `fallbackReason` and what was `restored`.
- `background` — never falls back; errors instead.
- `foreground` — always a real mouse click (the app is brought forward when `--app` is given; nothing is
  restored).

#### Usage

```bash
aux4 computer mac click --x <x> --y <y> [--app <name>] [--button left|right] [--count <n>] [--mode auto|background|foreground]
aux4 computer mac click --element <ref> [--app <name>] [--mode auto|background|foreground]
```

--x         X coordinate (window-relative with `--app`, screen points without)
--y         Y coordinate (window-relative with `--app`, screen points without)
--button    `left` or `right` (default: `left`)
--count     Click count, e.g. `2` for a double-click (default: `1`)
--element   Element ref from `read`/`find` to press instead of x/y
--app       Target app (default: the frontmost app)
--mode      `auto`, `background` or `foreground` (default: `auto`)

#### Example

Press Calculator's `7` button at (34, 211) in its window, while another app is in front:

```bash
aux4 computer mac click --app Calculator --x 34 --y 211
```

```json
{"action":"AXPress","app":"Calculator","button":"left","count":1,"element":{"label":"7","role":"AXButton"},"mode":"background","screen":{"x":496,"y":610},"x":34,"y":211}
```

When background isn't possible:

```json
{"app":"Calculator","button":"left","count":2,"fallbackReason":"multi-click has no accessibility equivalent","mode":"foreground","restored":{"cursor":true,"frontmost":true},"screen":{"x":496,"y":610},"x":34,"y":211}
```
