#### Description

Closes a window by pressing its close button through Accessibility, in the background. `closed` is `true` when the
window went away (`after` is `null`).

When the app asks first (an unsaved document shows a "save changes?" sheet), `closed` is `false` and the result
includes the `dialog` (kind, text, buttons, fields, as `dialog` reports it) and a `note`; answer it with
`dialog --app <name> --press <button>`. A document that was saved to a file closes without asking (macOS saves it).

#### Usage

```bash
aux4 computer mac window close [--app <name>] [--title <title> | --index <n>] [--mode <auto|background|foreground>]
```

--app     App whose window to use: name or bundle id (default: the frontmost app)
--title   Window title: exact match first, then contained (case-insensitive). Default: the app's main window
--index   Window index from `window list` (instead of `--title`)
--mode    `auto` (default), `background` (error instead of bringing the app forward) or `foreground` (bring the app forward first)

#### Example

```bash
aux4 computer mac window close --app TextEdit --title notes
```

```json
{
  "action": "close",
  "after": null,
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
  "closed": true,
  "method": "AXPress",
  "mode": "background"
}
```
