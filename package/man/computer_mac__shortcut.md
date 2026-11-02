#### Description

Presses a keyboard shortcut described as a `+`-separated combo, e.g. `cmd+c`, `cmd+shift+4`, `enter`,
`escape`. The last part is the key; everything before it is a modifier: `cmd`/`command`, `shift`,
`alt`/`option`, `ctrl`/`control`, `fn`. Modifiers and key names are parsed generically — there is no fixed
list of named shortcuts. Requires the Accessibility permission. Use `--delay` to wait before pressing,
e.g. right after a panel opens.

#### Usage

```bash
aux4 computer mac shortcut <keys> [--delay <ms>]
```

keys      Key combo, e.g. `cmd+shift+4` (positional)
--delay   Milliseconds to wait before pressing (default: `0`)

#### Example

```bash
aux4 computer mac shortcut "cmd+a"
aux4 computer mac shortcut "cmd+space" --delay 0
```

```json
{"keys":"cmd+a"}
```
