#### Description

The `mac` command groups every command that lets an AI agent see and operate this Mac: `permissions`,
`screenshot`, `ocr`, `wait`, `read`, `find`, `click`, `move`, `drag`, `type`, `shortcut`, `scroll`, `cursor`, `screen`,
`apps`, `windows`, `window` (list, move, resize, minimize, restore, close, fullscreen, raise), `open`, `focus`,
`quit`, `hide`, `unhide`, `state`, `menu`, `select`, `set`, `dialog`, `log`, `stop`, `resume` and `clipboard`, plus
`info` and `notes` for `aux4/computer`. This package is the macOS provider of `aux4/computer`: the generic
`aux4 computer <command>` runs the same command here on a Mac. The method for agents is the `aux4/computer` AI skill,
`aux4 ai skill computer prompt`, which includes this package's macOS notes. All commands print a single JSON object to stdout. This package only runs on macOS.

Actions run **in the background by default**: with `--app`, `click`, `type`, `scroll`, `shortcut` and
`clipboard copy/paste` act on that app through Accessibility without moving the cursor or changing the
frontmost app, and fall back to real input only when that isn't possible (restoring the cursor and
frontmost app afterwards). Every action reports `"mode":"background"` or `"mode":"foreground"`.
`focus`, `move` and `drag` are always foreground. With `--app`, coordinates are relative to the app's
front window (the same space as `screenshot --app`); without it they are screen points.

#### Usage

```bash
aux4 computer mac <command> [options]
```

#### Example

```bash
aux4 computer mac screen
```

```json
{"displays":[{"height":982,"id":1,"index":0,"main":true,"scale":2,"width":1512,"x":0,"y":0}]}
```
