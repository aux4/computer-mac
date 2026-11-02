#### Description

Raises a window above the app's other windows and brings the app to the front. This is foreground by nature:
the result always says `"mode":"foreground"`, nothing is restored afterwards, and `--mode background` is refused.

#### Usage

```bash
aux4 computer mac window raise [--app <name>] [--title <title> | --index <n>]
```

--app     App whose window to use: name or bundle id (default: the frontmost app)
--title   Window title: exact match first, then contained (case-insensitive). Default: the app's main window
--index   Window index from `window list` (instead of `--title`)
--mode    `auto` (default) or `foreground`; `background` is refused

#### Example

```bash
aux4 computer mac window raise --app TextEdit --title notes
```

```json
{
  "action": "raise",
  "after": {
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
    "title": "notes.txt",
    "focused": true,
    "main": true
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
  "frontmost": true,
  "method": "AXRaise",
  "mode": "foreground"
}
```
