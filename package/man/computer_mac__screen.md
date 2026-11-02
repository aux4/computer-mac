#### Description

Lists every active display: index (stable for this call, use it with `screenshot --display`), macOS
display id, whether it's the main display, bounds in screen points, and the backing scale factor (`2` on
Retina displays). Does not require any special permission.

#### Usage

```bash
aux4 computer mac screen
```

#### Example

```bash
aux4 computer mac screen
```

```json
{"displays":[{"height":982,"id":1,"index":0,"main":true,"scale":2,"width":1512,"x":0,"y":0}]}
```
