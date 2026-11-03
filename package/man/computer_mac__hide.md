#### Description

Hides an app (like cmd+h) without activating anything, and waits until it reports hidden. Hiding an already hidden
app changes nothing (`changed: false`). Hiding the frontmost app lets macOS make another app frontmost, as cmd+h does.
Recorded in the action log and refused while the stop switch is on.

#### Usage

```bash
aux4 computer mac hide <app>
```

--app   Application name or bundle id

#### Example

```bash
aux4 computer mac hide TextEdit
```

```json
{
  "app": "TextEdit",
  "before": {
    "hidden": false
  },
  "changed": true,
  "hidden": true,
  "method": "NSRunningApplication.hide",
  "mode": "background",
  "pid": 86813
}
```
