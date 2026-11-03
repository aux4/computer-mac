#### Description

Sets an element directly through Accessibility — **in the background** — and returns its value `before`
and `after`. The element is a `ref` from `find`, `state` or `read`. Give exactly one of:

- **`--value <v>`** — the value of a text field, text area, combo box or slider. Sliders, steppers and
  other numeric elements take a number. Replaces the whole value (to insert at the cursor, use `type`).
- **`--checked true|false`** — presses a checkbox, radio button or switch until it's in that state (a
  mixed checkbox may take two presses; already in that state is a no-op, `"method":"unchanged"`). A press
  that doesn't change the state is never repeated — some controls (e.g. TextEdit's bold/italic buttons)
  only act while their app is in front, so `auto` then presses once more with the app brought forward.
- **`--option <title>`** — picks an option of a pop-up button (through its menu), a combo box, or a radio
  group / tab group (by the button's title). Titles match case-insensitively; the error lists the
  available options.

In `auto` mode, if the app refuses the change in the background, the same change is retried with the app
brought forward, then the previous frontmost app and cursor are restored. `--mode background` errors
instead. An empty `--value` can't be passed (it means "not given"). Recorded in the action log (with
`--value` truncated); refused while the stop switch is on. Requires Accessibility.

#### Usage

```bash
aux4 computer mac set --element <ref> (--value <v> | --checked true|false | --option <title>) [--app <name|bundle id>] [--mode auto|background|foreground]
```

--element  Element ref (required)
--value    New value for a text field, text area, combo box or slider
--checked  `true` or `false` for a checkbox, radio button or switch
--option   Option title for a pop-up button, combo box or radio group
--app      App the element belongs to (default: the frontmost app)
--mode     `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac set --app TextEdit --element 0.0.0 --value "Replaced by aux4 computer mac set"
```

```json
{"after":"Replaced by aux4 computer mac set","app":"TextEdit","before":"Hello from aux4 computer-mac local check","element":{"label":"","ref":"0.0.0","role":"AXTextArea"},"method":"AXValue","mode":"background"}
```
