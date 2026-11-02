#### Description

Performs a mouse drag from one screen point to another: presses the left button at `--x`/`--y`, moves
through intermediate points, and releases at `--toX`/`--toY`. A drag always uses the real mouse — the
output says `"mode":"foreground"`. Requires the Accessibility permission.

#### Usage

```bash
aux4 computer mac drag --x <x> --y <y> --toX <x> --toY <y>
```

--x     Start X coordinate
--y     Start Y coordinate
--toX   End X coordinate
--toY   End Y coordinate

#### Example

```bash
aux4 computer mac drag --x 100 --y 200 --toX 400 --toY 200
```

```json
{"from":{"x":100,"y":200},"mode":"foreground","to":{"x":400,"y":200}}
```
