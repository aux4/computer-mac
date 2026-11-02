#### Description

Brings an already-running application to the foreground by name (case-insensitive, substring match
against the running app list). Fails if no running app matches. Does not require any special permission.

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
{"focused":"TextEdit","success":true}
```
