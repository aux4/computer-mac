#### Description

The `window` command group lists and changes an app's windows through Accessibility: `list`, `move`, `resize`,
`minimize`, `restore`, `close`, `fullscreen` and `raise`. Everything except `raise` works on a window of a background
app without bringing it forward or moving the cursor; results report `"mode":"background"`. If the user's frontmost
app changed anyway, it is put back and the result includes `restored`.

A window is picked with `--title` (exact, then contained, case-insensitive) or `--index` (from `window list`);
by default the app's main window. Every changing action returns the window's state `before` and `after`
(`frame` in screen points, `minimized`, `fullscreen`), is recorded in the action log (`window move`, ...) and is
refused while the stop switch is on. `list` is read-only.

#### Usage

```bash
aux4 computer mac window <list|move|resize|minimize|restore|close|fullscreen|raise> [--app <name>] [--title <title> | --index <n>]
```

#### Example

```bash
aux4 computer mac window move --app TextEdit --title notes --x 200 --y 150
```
