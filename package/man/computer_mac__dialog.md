#### Description

Detects an open alert, sheet, dialog or save/open panel of an app and describes it; with `--press`,
presses one of its buttons by title — **in the background** by default.

Detection looks at the app's windows: a sheet attached to a window first, then a dialog window. Without
`--app`, it checks the frontmost app, then system alerts (shown by macOS helper processes). It returns
`"dialog":null` when nothing is open, or:

- **`kind`** — `sheet`, `dialog`, `system-alert`, `save-panel` or `open-panel`
- **`title`**, **`text`** — its title and its static texts (the message), and `window` for a sheet's window
- **`buttons`** — each with `title`, `default` (pressed by Return) and `cancel` (pressed by Escape) flags,
  `enabled`, and `ref` / `frame` / `center` / `windowCenter` like a `find` match (up to 25)
- **`fields`** — text fields, checkboxes, pop-ups and combo boxes inside it, like `find` matches (up to 15;
  secure fields never report their value)

`--press <title>` matches a button case-insensitively (a trailing `…` and curly apostrophes don't matter:
`"Don't Save"` matches `Don’t Save`), presses it, and reports `closed` (the dialog went away) and `next`
when pressing it opened another dialog. The error lists the buttons when the title doesn't match. In `auto`
mode, if the press isn't possible in the background, the app is brought forward for it and the previous
frontmost app and cursor are restored. Pressing is recorded in the action log and refused while the stop
switch is on; detecting is read-only. Requires Accessibility.

#### Usage

```bash
aux4 computer mac dialog [--app <name|bundle id>] [--press <button title>] [--mode auto|background|foreground]
```

--app    App to check (default: the frontmost app, then system alerts)
--press  Title of the button to press
--mode   `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac dialog --app TextEdit
```

```json
{"app":"TextEdit","dialog":{"app":"TextEdit","buttons":[{"cancel":false,"default":false,"ref":"0.4.6","title":"Delete"},{"cancel":true,"default":false,"ref":"0.4.7","title":"Cancel"},{"cancel":false,"default":true,"ref":"0.4.8","title":"Save"}],"fields":[{"ref":"0.4.2","role":"AXTextField","value":"Untitled"}],"kind":"save-panel","text":["Do you want to keep this new document “Untitled”?"],"title":"","window":"Untitled"}}
```

```bash
aux4 computer mac dialog --app TextEdit --press "Delete"
```

```json
{"app":"TextEdit","closed":true,"dialog":{"kind":"save-panel","title":""},"kind":"save-panel","method":"AXPress","mode":"background","pressed":"Delete"}
```
