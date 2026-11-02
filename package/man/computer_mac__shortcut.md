#### Description

Presses a keyboard shortcut described as a `+`-separated combo, e.g. `cmd+c`, `cmd+shift+4`, `enter`,
`escape`. The last part is the key; everything before it is a modifier: `cmd`/`command`, `shift`,
`alt`/`option`, `ctrl`/`control`, `fn`. Modifiers and key names are parsed generically — there is no fixed
list of named shortcuts. Requires the Accessibility permission. Use `--delay` to wait before pressing,
e.g. right after a panel opens.

- **Without `--app`** the shortcut is system-wide (e.g. `cmd+space` for Spotlight) and is always pressed
  as real input (`"mode":"foreground"`); `--mode background` is refused.
- **With `--app`** (`--mode auto`, the default) the shortcut is run **in the background** when possible:
  if the app has an enabled menu item with that key equivalent (e.g. `cmd+1` → View > Basic in Calculator), that item is
  pressed through Accessibility; if the app is already frontmost, the keystrokes are sent to that app
  only. Shortcuts that act on the focused text (`cmd+a`, `cmd+z`, …) are disabled in a background app's
  menus, so for those `auto` falls back to real input: the app is brought forward, the shortcut pressed,
  and the cursor and previously frontmost app restored. `--mode background` errors instead of falling back.

#### Usage

```bash
aux4 computer mac shortcut <keys> [--app <name>] [--delay <ms>] [--mode auto|background|foreground]
```

keys      Key combo, e.g. `cmd+shift+4` (positional)
--app     Send the shortcut to this app (default: system-wide)
--delay   Milliseconds to wait before pressing (default: `0`)
--mode    `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac shortcut "cmd+1" --app Calculator
```

```json
{"app":"Calculator","keys":"cmd+1","menuItem":"Basic","method":"menu","mode":"background"}
```

```bash
aux4 computer mac shortcut "cmd+space"
```

```json
{"keys":"cmd+space","mode":"foreground"}
```
