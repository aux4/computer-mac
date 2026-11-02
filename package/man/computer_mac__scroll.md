#### Description

Scrolls in the target app (`--app`, or the frontmost app). `--dy` is the vertical delta in pixels
(negative scrolls down), `--dx` the horizontal delta. `--x`/`--y` pick where to scroll — **relative to the
app's front window with `--app`**, screen points without; if omitted, the focused element's scroll area is
used. Requires the Accessibility permission.

By default (`--mode auto`) scrolling happens **in the background**: the scroll area at that point is
scrolled by moving its scroll bar through Accessibility (`"method":"accessibility"`, with the new
`vertical`/`horizontal` position from `0` to `1`). With `--app`, if there's no accessible scroll area, a
scroll event is posted to that app only (`"method":"postToPid"`). Otherwise `auto` falls back to a real
scroll wheel event at the point, then restores the cursor and frontmost app. `--mode background` errors
instead of falling back; `--mode foreground` always moves the cursor and scrolls for real.

**Note:** pass negative values with `=`, e.g. `--dy=-200`.

#### Usage

```bash
aux4 computer mac scroll [--x <x> --y <y>] [--dx=<pixels>] [--dy=<pixels>] [--app <name>] [--mode auto|background|foreground]
```

--x      X coordinate to scroll at (window-relative with `--app`, screen points without)
--y      Y coordinate to scroll at (window-relative with `--app`, screen points without)
--dx     Horizontal scroll delta in pixels (default: `0`)
--dy     Vertical scroll delta in pixels, negative scrolls down (default: `0`)
--app    App to scroll (default: the frontmost app)
--mode   `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac scroll --app TextEdit --x 290 --y 250 --dy=-400
```

```json
{"app":"TextEdit","dx":0,"dy":-400,"method":"accessibility","mode":"background","screen":{"x":442,"y":323},"vertical":0.317}
```
