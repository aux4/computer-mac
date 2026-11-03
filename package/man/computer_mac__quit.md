#### Description

Quits an app the way the Quit menu item does (`terminate`), without bringing it forward, and waits up to
`--timeout` for it to exit (`terminated: true`).

- An app with unsaved changes may answer with a "save changes?" sheet or alert instead of quitting: the result then
  has `terminated: false`, the `dialog` and a `note`. Answer it with `dialog --app <name> --press <button>` (the app
  quits after "Delete"/"Don't Save"), or press "Cancel" to keep it running.
- A sheet or alert that is already open keeps the app from quitting: it is reported the same way; answer it, then
  run `quit` again.
- `--force true` kills the app (`forceTerminate`): unsaved changes are lost. Force-quitting Finder is refused.
- Session processes (Dock, loginwindow, SystemUIServer, Control Center, Notification Center, Spotlight, Window
  Manager) are never quit.
- If the app neither quits nor asks within `--timeout`, the command fails (exit 1) with `terminated: false`.

Recorded in the action log and refused while the stop switch is on.

#### Usage

```bash
aux4 computer mac quit <app> [--force <true|false>] [--timeout <duration>]
```

--app      Application name or bundle id
--force    Force-quit; unsaved changes are lost (default: `false`)
--timeout  How long to wait for the app to exit, e.g. `5s`, `500ms` (default: `5s`)

#### Example

```bash
aux4 computer mac quit TextEdit
```

```json
{
  "app": "TextEdit",
  "bundleId": "com.apple.TextEdit",
  "force": false,
  "method": "terminate",
  "mode": "background",
  "pid": 86813,
  "terminated": true,
  "waited": 0.14
}
```
