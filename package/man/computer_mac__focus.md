#### Description

Brings an already-running application to the foreground by name (case-insensitive, substring match
against the running app list). Fails if no running app matches. This is a foreground action by nature —
the output always says `"mode":"foreground"`. Most commands don't need it: `click`, `type`, `scroll`,
`shortcut` and `clipboard` act on a background app with `--app`.

#### Usage

```bash
aux4 computer mac focus <app>
```

app   Application name (positional)

#### Example

```bash
aux4 computer mac focus "TextEdit"
```

```json
{"focused":"TextEdit","mode":"foreground","success":true}
```
