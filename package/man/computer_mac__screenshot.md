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
- **`--annotate true`** draws a numbered box on each element (set-of-marks) from the accessibility tree and adds
  `marks` to the output: `n` (the number drawn), `ref` (for `click --element`, `set --element`...), `role`, `label`,
  `value` (for fields), `frame` and `center` in screen points, `windowCenter` relative to the window (with `--app`)
  and `image` (the box in pixels of the PNG). Numbers run in reading order; each tag is placed where it doesn't cover
  another one. `center` is the middle of the element's visible part. Needs Accessibility too.
  - `--roles actionable` (default) marks buttons, links, text fields and areas, checkboxes, radio buttons, pop-ups,
    menu buttons and items, combo boxes, sliders, steppers, tabs, rows, disclosure triangles and switches;
    `--roles all` also marks text, images, headings, cells and indicators.
  - Elements scrolled out of view or outside the captured area are left out.
  - At most `--limit` marks (default `150`) are drawn; when there are more, `truncated: true` and a `note` say so.
  - Without `--app`, the frontmost app's windows on that display are annotated (`app` names it).

#### Usage

```bash
aux4 computer mac screenshot [--output <path>] [--display <index>] [--app <name>] [--maxWidth <pixels>] [--annotate <true|false>] [--roles <actionable|all>] [--limit <n>]
```

--output     File path to save the PNG to (default: a generated temp file path)
--display    Display index to capture (default: `0`)
--app        Capture this app's front window instead of a display
--maxWidth   Resize down if wider than this, preserving aspect ratio (default: `1568`)
--annotate   Draw numbered boxes on the elements and return them as `marks` (default: `false`)
--roles      With `--annotate`: `actionable` (default) or `all`
--limit      With `--annotate`: most marks to draw (default: `150`)

#### Example

```bash
aux4 computer mac screenshot --app "Calculator" --output /tmp/calculator.png
```

```json
{"app":"Calculator","height":408,"path":"/tmp/calculator.png","scale":1,"width":230,"window":{"frame":{"height":408,"width":230,"x":462,"y":399},"id":295,"title":"Calculator"}}
```

With `--annotate`, the image has a numbered box on every control and the output lists them:

```bash
aux4 computer mac screenshot --app Calculator --annotate true --output /tmp/calculator.png
```

```json
{
  "annotated": true,
  "app": "Calculator",
  "height": 408,
  "marks": [
    {
      "center": {"x": 496, "y": 610},
      "frame": {"height": 48, "width": 48, "x": 472, "y": 586},
      "image": {"height": 48, "width": 48, "x": 10, "y": 187},
      "label": "7",
      "n": 10,
      "ref": "0.0.0.1.0.6",
      "role": "AXButton",
      "windowCenter": {"x": 34, "y": 211}
    }
  ],
  "path": "/tmp/calculator.png",
  "roles": "actionable",
  "scale": 1,
  "width": 230,
  "window": {"frame": {"height": 408, "width": 230, "x": 462, "y": 399}, "id": 295, "title": "Calculator"}
}
```

(One of the 25 marks shown.) Press mark 10 with `aux4 computer mac click --element 0.0.0.1.0.6 --app Calculator`.
