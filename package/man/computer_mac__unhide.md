#### Description

Shows a hidden app again **without** bringing it to the front: its windows come back behind the frontmost app. If
the app activates itself anyway, the user's frontmost app is put back (`restored`). Recorded in the action log and
refused while the stop switch is on.

#### Usage

```bash
aux4 computer mac unhide <app>
```

--app   Application name or bundle id

#### Example

```bash
aux4 computer mac unhide TextEdit
```

```json
{
  "app": "TextEdit",
  "before": {
    "hidden": true
  },
  "changed": true,
  "hidden": false,
  "method": "NSRunningApplication.unhide",
  "mode": "background",
  "pid": 86813
}
```
