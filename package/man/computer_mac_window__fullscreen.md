#### Description

Enters (`true`, the default) or leaves (`false`) full screen by setting the window's `AXFullScreen` attribute and
waits (up to 5s) for it to take effect. Entering full screen moves the window to its own Space, which macOS shows;
it is not something to do on a Mac someone is using without asking.

#### Usage

```bash
aux4 computer mac window fullscreen [true|false] [--app <name>] [--title <title> | --index <n>] [--mode <auto|background|foreground>]
```

--app     App whose window to use: name or bundle id (default: the frontmost app)
--title   Window title: exact match first, then contained (case-insensitive). Default: the app's main window
--index   Window index from `window list` (instead of `--title`)
--enabled `true` to enter full screen (default), `false` to leave it
--mode    `auto` (default), `background` (error instead of bringing the app forward) or `foreground` (bring the app forward first)

#### Example

```bash
aux4 computer mac window fullscreen false --app TextEdit
```

```json
{
  "action": "fullscreen",
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
    "fullscreen": true,
    "index": 0,
    "minimized": false,
    "ref": "0",
    "title": "notes.txt"
  },
  "method": "AXFullScreen",
  "mode": "background",
  "requested": {
    "fullscreen": false
  }
}
```
