#### Description

Captures a screenshot using ScreenCaptureKit and saves it as a PNG. Requires the Screen Recording
permission (see `computer mac permissions`).

- With no `--app`, captures the display at `--display` (an index from `computer mac screen`, default `0`).
- With `--app`, captures that application's frontmost on-screen window instead.
- The captured image is resized down (preserving aspect ratio) if wider than `--maxWidth`, so it fits
  common vision-model input limits.
- If `--output` is omitted, the PNG is written to a generated path in the system temp directory.

#### Usage

```bash
aux4 computer mac screenshot [--output <path>] [--display <index>] [--app <name>] [--maxWidth <pixels>]
```

--output     File path to save the PNG to (default: a generated temp file path)
--display    Display index to capture (default: `0`)
--app        Capture this app's frontmost window instead of a display
--maxWidth   Resize down if wider than this, preserving aspect ratio (default: `1568`)

#### Example

```bash
aux4 computer mac screenshot --app "TextEdit" --output /tmp/textedit.png
```

```json
{"path":"/tmp/textedit.png","width":1024,"height":768,"scale":1}
```
