#### Description

Lists on-screen windows (layer `0`, i.e. normal app windows — not the desktop, menu bar, or system
overlays): window id, owning app name and pid, title, and frame in screen points. Does not require any
special permission.

#### Usage

```bash
aux4 computer mac windows
```

#### Example

```bash
aux4 computer mac windows
```

```json
{"windows":[{"app":"TextEdit","frame":{"height":600,"width":800,"x":100,"y":100},"id":42,"pid":1234,"title":"Untitled"}]}
```
