#### Description

Moves a window so its top-left corner is at `--x`/`--y` in screen points (origin: the top-left of the main
display) by setting its accessibility position, in the background. Returns the window `before` and `after` and the
`requested` position. Negative values (a display left of the main one) need `=`: `--x=-1200`.

A full-screen window, or one whose app doesn't allow moving it, is refused with an error naming the reason.

#### Usage

```bash
aux4 computer mac window move --x <points> --y <points> [--app <name>] [--title <title> | --index <n>] [--mode <auto|background|foreground>]
```

--app     App whose window to use: name or bundle id (default: the frontmost app)
--title   Window title: exact match first, then contained (case-insensitive). Default: the app's main window
--index   Window index from `window list` (instead of `--title`)
--x       Screen x of the window's top-left corner
--y       Screen y of the window's top-left corner
--mode    `auto` (default), `background` (error instead of bringing the app forward) or `foreground` (bring the app forward first)

#### Example

```bash
aux4 computer mac window move --app TextEdit --title notes --x 200 --y 150
```

```json
{
  "action": "move",
  "after": {
    "frame": {
      "height": 422,
      "width": 656,
      "x": 200,
      "y": 150
    },
    "fullscreen": false,
    "index": 0,
    "minimized": false,
    "ref": "0",
    "title": "notes.txt"
  },
  "app": "TextEdit",
  "before": {
    "frame": {
      "height": 422,
      "width": 656,
      "x": 152,
      "y": 73
    },
    "fullscreen": false,
    "index": 0,
    "minimized": false,
    "ref": "0",
    "title": "notes.txt"
  },
  "method": "AXPosition",
  "mode": "background",
  "requested": {
    "x": 200,
    "y": 150
  }
}
```
