#### Description

Captures a screenshot and saves it as a PNG. Requires the Screen Recording permission (see
`computer mac permissions`). Capturing never moves the cursor or changes the frontmost app.

- With no `--app`, captures the display at `--display` (an index from `computer mac screen`, default `0`).
- With `--app`, captures that application's front window — **even when it is covered by other windows**.
  The output includes the window's `frame` in screen points. Positions in this image map to `click --app`,
  `scroll --app` coordinates: divide the image pixel position by `scale`.
- The captured image is resized down (preserving aspect ratio) if wider than `--maxWidth`, so it fits
  common vision-model input limits. `scale` is image pixels per point.
- If `--output` is omitted, the PNG is written to a generated path in the system temp directory.

#### Usage

```bash
aux4 computer mac screenshot [--output <path>] [--display <index>] [--app <name>] [--maxWidth <pixels>]
```

--output     File path to save the PNG to (default: a generated temp file path)
--display    Display index to capture (default: `0`)
--app        Capture this app's front window instead of a display
--maxWidth   Resize down if wider than this, preserving aspect ratio (default: `1568`)

#### Example

```bash
aux4 computer mac screenshot --app "Calculator" --output /tmp/calculator.png
```

```json
{"app":"Calculator","height":408,"path":"/tmp/calculator.png","scale":1,"width":230,"window":{"frame":{"height":408,"width":230,"x":462,"y":399},"id":295,"title":"Calculator"}}
```
