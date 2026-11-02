#### Description

Searches the accessibility tree of the frontmost app (or `--app`) for elements whose label or value
contains `--text` (case-insensitive) and/or whose role equals `--role`. At least one of `text` or `role`
must be given. Each match includes everything `read` returns plus a `center` point (`{x, y}`), ready to
pass straight into `computer mac click --x --y`. Requires the Accessibility permission.

#### Usage

```bash
aux4 computer mac find <text> [--role <AXRole>] [--app <name>]
```

text     Text to search for in element label/value (positional)
--role   Filter by AX role, e.g. `AXButton`
--app    App to search (default: the frontmost app)

#### Example

```bash
aux4 computer mac find "Save" --role AXButton --app "TextEdit"
```

```json
{"app":"TextEdit","matches":[{"ref":"0.1.3","role":"AXButton","label":"Save","value":"","frame":{"x":200,"y":600,"width":80,"height":24},"center":{"x":240,"y":612},"enabled":true,"focused":false}]}
```
