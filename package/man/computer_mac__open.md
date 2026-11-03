#### Description

Opens an app, a file or a URL. By default (`--mode auto`) it happens **in the background**: nothing is
brought to the front, and if the app activates itself anyway the previously frontmost app is put back
(`restored`). `--mode foreground` opens and activates the app. No special permission is needed (`--wait`
reads windows through Accessibility).

- **An app** — by name (`TextEdit`), bundle id (`com.apple.TextEdit`) or `.app` path. An app that isn't
  running is launched without activating; an app that is already running is left as it is
  (`"alreadyRunning":true`).
- **`--file <path>`** — opens the file in `--app`, or in its default app when `--app` is omitted. The file
  must exist.
- **`--url <url>`** — opens the URL (with its scheme, e.g. `https://aux4.io`) in `--app` or its default
  handler.
- **`--wait <timeout>`** — returns once the app has a window — with `--file`, the window showing that file
  (by its document or title) — and includes it (`title`, `frame`, `ref`) and how long it `waited`. Times
  out with exit code `1` and a JSON error.
- **`--hidden true`** — launches the app hidden (its windows still exist for `state`, `find` and `set`, but
  aren't on screen). Can't be combined with `--mode foreground`.

The output includes the app's `name`, `pid` and `bundleId`. Recorded in the action log; refused while the
stop switch is on.

#### Usage

```bash
aux4 computer mac open [<app>] [--file <path>] [--url <url>] [--wait <timeout>] [--hidden true] [--mode auto|background|foreground]
```

app       Application name, bundle id or .app path (positional; optional with `--file` / `--url`)
--file    File to open
--url     URL to open
--wait    Wait up to this long for the window, e.g. `10s` (default: don't wait)
--hidden  `true` to launch the app hidden (default: `false`)
--mode    `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac open --file /tmp/notes.txt --app com.apple.TextEdit --wait 10s
```

```json
{"app":"TextEdit","bundleId":"com.apple.TextEdit","file":"/tmp/notes.txt","mode":"background","opened":"com.apple.TextEdit","pid":71767,"waited":0.04,"window":{"frame":{"height":422,"width":656,"x":152,"y":73},"ref":"0","title":"notes.txt"}}
```
