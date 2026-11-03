#### Description

Lists an app's windows from its accessibility tree, including hidden and minimized ones (which `windows`, the
on-screen list, leaves out). Each entry has `index` (use with `--index`), `ref` (the window's element ref), `title`,
`frame` (screen points), `minimized`, `fullscreen`, and `main`/`focused`/`subrole` when they apply. Read-only: it works
while the stop switch is on. At most 50 windows are listed.

#### Usage

```bash
aux4 computer mac window list [--app <name>]
```

--app   App whose windows to list: name or bundle id (default: the frontmost app)

#### Example

```bash
aux4 computer mac window list TextEdit
```

```json
{
  "app": "TextEdit",
  "pid": 86813,
  "windows": [
    {
      "frame": {
        "height": 422,
        "width": 656,
        "x": 152,
        "y": 73
      },
      "fullscreen": false,
      "index": 0,
      "minimized": false,
      "ref": "0",
      "title": "notes.txt"
    }
  ]
}
```
