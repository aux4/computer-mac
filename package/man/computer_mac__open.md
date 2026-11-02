#### Description

Launches an application by name, via `/usr/bin/open -a`. If the app isn't already running, macOS starts
it; if it's running, this typically brings it forward. Does not require any special permission.

#### Usage

```bash
aux4 computer mac open <app>
```

app   Application name (positional)

#### Example

```bash
aux4 computer mac open "TextEdit"
```

```json
{"opened":"TextEdit"}
```
