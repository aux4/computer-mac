#### Description

The `mac` command groups every command that lets an AI agent see and operate this Mac: `permissions`,
`screenshot`, `read`, `find`, `click`, `move`, `drag`, `type`, `shortcut`, `scroll`, `cursor`, `screen`,
`apps`, `windows`, `open`, `focus`, and `clipboard`. All commands print a single JSON object to stdout and
use screen points for coordinates. This package only runs on macOS.

#### Usage

```bash
aux4 computer mac <command> [options]
```

#### Example

```bash
aux4 computer mac screen
```

```json
{"displays":[{"height":982,"id":1,"index":0,"main":true,"scale":2,"width":1512,"x":0,"y":0}]}
```
