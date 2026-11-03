#### Description

Resizes a window to `--width`/`--height` points by setting its accessibility size, in the background. Give one of
them to keep the other side as it is. Apps enforce their own minimum and maximum sizes: when the window ends up at a
different size than asked, the result has a `note` with the size it kept.

#### Usage

```bash
aux4 computer mac window resize [--width <points>] [--height <points>] [--app <name>] [--title <title> | --index <n>] [--mode <auto|background|foreground>]
```

--app     App whose window to use: name or bundle id (default: the frontmost app)
--title   Window title: exact match first, then contained (case-insensitive). Default: the app's main window
--index   Window index from `window list` (instead of `--title`)
--width   New width in points (default: keep)
--height  New height in points (default: keep)
--mode    `auto` (default), `background` (error instead of bringing the app forward) or `foreground` (bring the app forward first)

#### Example

```bash
aux4 computer mac window resize --app TextEdit --title notes --width 50
```

```json
{
  "action": "resize",
  "after": {
    "frame": {
      "height": 422,
      "width": 115,
      "x": 152,
      "y": 73
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
  "method": "AXSize",
  "mode": "background",
  "note": "the app kept the window at 115x422 (its minimum/maximum size)",
  "requested": {
    "width": 50
  }
}
```
