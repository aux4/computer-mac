#### Description

Minimizes a window to the Dock by setting its accessibility `AXMinimized` attribute, in the background, and
waits (up to 3s) until the window reports it is minimized.

#### Usage

```bash
aux4 computer mac window minimize [--app <name>] [--title <title> | --index <n>] [--mode <auto|background|foreground>]
```

--app     App whose window to use: name or bundle id (default: the frontmost app)
--title   Window title: exact match first, then contained (case-insensitive). Default: the app's main window
--index   Window index from `window list` (instead of `--title`)
--mode    `auto` (default), `background` (error instead of bringing the app forward) or `foreground` (bring the app forward first)

#### Example

```bash
aux4 computer mac window minimize --app TextEdit --title notes
```

```json
{
  "action": "minimize",
  "after": {
    "frame": {
      "height": 422,
      "width": 656,
      "x": 152,
      "y": 73
    },
    "fullscreen": false,
    "index": 0,
    "minimized": true,
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
  "method": "AXMinimized",
  "mode": "background"
}
```
