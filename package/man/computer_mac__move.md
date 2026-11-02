#### Description

Moves the mouse cursor to the given screen point without clicking. This always moves the real cursor —
the output says `"mode":"foreground"`. Requires the Accessibility permission.

#### Usage

```bash
aux4 computer mac move --x <x> --y <y>
```

--x   X coordinate in screen points
--y   Y coordinate in screen points

#### Example

```bash
aux4 computer mac move --x 500 --y 300
```

```json
{"mode":"foreground","x":500,"y":300}
```
