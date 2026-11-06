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
  secure fields never report their value). When a field has no `AXTitle`/`AXDescription` (NSSavePanel's
  name field and its "File Format" pop-up report neither), `label` falls back to its `AXTitleUIElement`
  pointer, then the nearest static text to its left on the same row, then the nearest one directly above
  — e.g. the Save panel's name field now reports `label: "Save As:"` and the format pop-up
  `label: "File Format:"` instead of `""`. This applies to `find`, `read` and `state` too.

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
{"app":"TextEdit","dialog":{"app":"TextEdit","buttons":[{"cancel":false,"center":{"x":389,"y":490},"default":false,"enabled":true,"focused":false,"frame":{"height":32,"width":86,"x":346,"y":474},"label":"Delete","ref":"0.8.13","role":"AXButton","title":"Delete","value":"","windowCenter":{"x":56,"y":359}},{"cancel":false,"center":{"x":559,"y":490},"default":false,"enabled":true,"focused":false,"frame":{"height":32,"width":86,"x":516,"y":474},"label":"Cancel","ref":"0.8.14","role":"AXButton","title":"Cancel","value":"","windowCenter":{"x":226,"y":359}},{"cancel":false,"center":{"x":639,"y":490},"default":false,"enabled":true,"focused":false,"frame":{"height":32,"width":86,"x":596,"y":474},"label":"Save","ref":"0.8.15","role":"AXButton","title":"Save","value":"","windowCenter":{"x":306,"y":359}}],"fields":[{"center":{"x":540.5,"y":312},"enabled":true,"focused":false,"frame":{"height":22,"width":235,"x":423,"y":301},"label":"Save As:","ref":"0.8.5","role":"AXTextField","value":"Untitled","windowCenter":{"x":207.5,"y":181}},{"center":{"x":527,"y":387.5},"enabled":true,"focused":false,"frame":{"height":25,"width":214,"x":420,"y":375},"label":"Where:","ref":"0.8.9","role":"AXPopUpButton","value":"Documents","windowCenter":{"x":194,"y":256.5}}],"frame":{"height":388,"width":362,"x":333,"y":131},"kind":"save-panel","ref":"0.8","text":["Do you want to keep this new document “Untitled”?","You can choose to save your changes, or delete this document immediately. You can’t undo this action.","Save As:","Where:"],"title":"save","window":"Untitled"}}
```

```bash
aux4 computer mac dialog --app TextEdit --press "Delete"
```

```json
{"app":"TextEdit","closed":true,"dialog":{"kind":"save-panel","title":"save"},"kind":"save-panel","method":"AXPress","mode":"background","pressed":"Delete"}
```
