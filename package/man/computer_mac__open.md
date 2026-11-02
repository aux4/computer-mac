#### Description

Opens an application by name. By default (`--mode auto`) it happens **in the background**: an app that
isn't running is launched without being brought to the front; an app that is already running is left as
it is (`"alreadyRunning":true`). If a launching app activates itself anyway, the previously frontmost app
is put back. `--mode foreground` opens it the regular way, bringing it to the front. Does not require any
special permission.

#### Usage

```bash
aux4 computer mac open <app> [--mode auto|background|foreground]
```

app      Application name (positional)
--mode   `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac open "TextEdit"
```

```json
{"mode":"background","opened":"TextEdit"}
```
