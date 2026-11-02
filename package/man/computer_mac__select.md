#### Description

Selects text in a text field or text area through Accessibility — **in the background**: no keystrokes,
no focus change, the app can stay behind other windows. Acts on the app's focused element, or on
`--element <ref>` (from `find` or `state`). Give exactly one of:

- **`--all true`** — select the whole text
- **`--text <text>`** — select a match (case-insensitive); `--occurrence N` picks the Nth (default `1`)
- **`--start N --length N`** — select a range of characters (offsets from `0`)

Returns the `selected` text (up to 4000 characters, `selectedTruncated` beyond that), its `range`, and the
`element` (role, label, ref). A follow-up `clipboard copy --app` then copies it in the background.
`shortcut cmd+a --app <app>` uses the same selection when the app's Select All menu item is disabled
(which it is while the app is in the background).

Errors name the problem: text not found (with how many occurrences there are), a range past the end of the
text, or an element that doesn't take an accessibility selection. In `auto` mode, if the background
selection isn't possible, `--all` falls back to bringing the app forward and pressing `cmd+a`, and the other
forms retry the same selection with the app in front; the previous frontmost app and cursor are restored.
Recorded in the action log; refused while the stop switch is on. Requires Accessibility.

#### Usage

```bash
aux4 computer mac select [--app <name|bundle id>] (--all true | --text <text> [--occurrence N] | --start N --length N) [--element <ref>] [--mode auto|background|foreground]
```

--app         App to select in (default: the frontmost app)
--all         `true` to select all the text
--text        Text to select
--occurrence  Which match of `--text` (default: `1`)
--start       First character of the range (from `0`)
--length      Number of characters in the range
--element     Text element ref (default: the app's focused element)
--mode        `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac select --app TextEdit --text aux4
```

```json
{"app":"TextEdit","element":{"label":"","ref":"0.0.0","role":"AXTextArea"},"method":"accessibility","mode":"background","range":{"length":4,"start":11},"selected":"aux4"}
```
