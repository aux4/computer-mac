#### Description

Posts a scroll-wheel event. If `--x`/`--y` are given, the cursor is moved there first so the scroll
targets that location; otherwise it scrolls at the current cursor position. `--dy` is vertical delta in
pixels (negative scrolls down), `--dx` is horizontal delta. Requires the Accessibility permission.

#### Usage

```bash
aux4 computer mac scroll [--x <x> --y <y>] --dx <pixels> --dy <pixels>
```

--x    X coordinate to move the cursor to before scrolling
--y    Y coordinate to move the cursor to before scrolling
--dx   Horizontal scroll delta in pixels (default: `0`)
--dy   Vertical scroll delta in pixels (default: `0`)

#### Example

```bash
aux4 computer mac scroll --x 500 --y 400 --dy -200
```

```json
{"dx":0,"dy":-200}
```
