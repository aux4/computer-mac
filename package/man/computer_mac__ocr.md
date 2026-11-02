#### Description

Recognizes the text that is visible in pixels — on the screen, in one app's window, or in an existing PNG —
and returns each line of text as an entry in `matches` (the same key `find` uses) with its position in
the same coordinates `click` uses. Recognition runs on this
Mac with the system's built-in text recognition: no network, nothing to download.

Use it when the accessibility tree doesn't expose what's on screen (canvas-drawn UIs, images, games,
remote desktops, some web content), or to confirm that what an app reports is what is actually shown.
When an app does expose its UI, `find` is faster and exact; `ocr` reads only what is rendered.

- **No `--app` / `--image`** — captures the main display. `frame` and `center` are screen points.
- **`--app`** — captures that app's front window, **even when it's covered by other windows**. `frame`
  and `center` are screen points, and `windowCenter` is relative to the window — the space
  `click --app`/`scroll --app` and `screenshot --app` use. The output includes the window `frame`.
- **`--image`** — recognizes a PNG instead of capturing. Needs no Screen Recording permission.
  Positions are image pixels divided by `--scale` (default `1`; pass the `scale` from `screenshot` to
  get points).
- **`--text`** — only returns the lines containing that text (none → `"matches": []`, exit `0`, like `find`), ignoring case, whitespace and commas
  (recognition sometimes reads `1,792` as `1 ,792`, and apps differ on digit grouping, so `1792` matches
  `1,792` and the other way round). Each line also gets a `match` with the
  `frame`/`center`/`windowCenter` of just the matched text, for clicking a word inside a longer line.
- **`--level`** — `accurate` (default) or `fast`. `fast` is noticeably weaker: on light-on-dark UIs such
  as Calculator it can return nothing. Language correction is always on.
- **`--languages`** — comma-separated recognition languages in priority order (`en-US,pt-BR`); an
  unsupported one errors with the supported list.
- **`--mode`** — capturing never needs input, so `auto` (default) and `background` capture in place
  without changing the frontmost app. If the app's window isn't on screen (the app is hidden, or the window is on another Space), `auto`
  brings the app to the front for the capture and restores the previously frontmost app and cursor
  (`"mode":"foreground"` plus `fallbackReason` and `restored`); `background` errors instead.
  `foreground` always brings the app forward for the capture, then restores.

Windows and the screen are captured at a density of at least 2 pixels per point, so small text has a
better chance. Each entry has `text` (OCR has no labels), `confidence`, `frame`, `center`, and `windowCenter` with `--app`.
Entries come back in reading order (top to bottom, left to right). `confidence` is between
`0` and `1`.

**Note:** very small or low-contrast text (single-digit buttons, thin glyphs) can be missed, and symbols
can be misread (Calculator's `±` comes back as `+/_`). Check `confidence`, and prefer `find` where the app
exposes the element. A minimized window can't be read; restore it first.

Requires the Screen Recording permission, except with `--image`.

#### Usage

```bash
aux4 computer mac ocr [--app <name>] [--image <png>] [--text <filter>] [--level accurate|fast] [--languages <list>] [--mode auto|background|foreground] [--scale <pixels per point>]
```

--app        Read this app's front window instead of the main display (default: the main display)
--image      Recognize an existing PNG instead of capturing (cannot be combined with `--app`)
--text       Only return lines containing this text (default: all lines)
--level      `accurate` or `fast` (default: `accurate`)
--languages  Comma-separated recognition languages, e.g. `en-US,pt-BR` (default: the system's default)
--mode       `auto`, `background` or `foreground` (default: `auto`)
--scale      With `--image`: image pixels per point (default: `1`)

#### Example

Find Calculator's result even though Calculator is behind other windows, then press a button that OCR
located:

```bash
aux4 computer mac ocr --app Calculator --text "1,792"
```

```json
{"app":"Calculator","height":408,"level":"accurate","matches":[{"center":{"x":645,"y":511.5},"confidence":1,"frame":{"height":33,"width":74,"x":608,"y":495},"match":{"center":{"x":645,"y":511.5},"frame":{"height":33,"width":74,"x":608,"y":495},"windowCenter":{"x":183,"y":112.5}},"text":"1,792","windowCenter":{"x":183,"y":112.5}}],"mode":"background","scale":2,"source":"window","text":"1,792","width":230,"window":{"frame":{"height":408,"width":230,"x":462,"y":399},"id":331,"title":"Calculator"}}
```

```bash
aux4 computer mac click --app Calculator --x 34 --y 211.5
```

```json
{"action":"AXPress","app":"Calculator","button":"left","count":1,"element":{"label":"7","role":"AXButton"},"mode":"background","screen":{"x":496,"y":610.5},"x":34,"y":211.5}
```

Recognize a saved PNG:

```bash
aux4 computer mac ocr --image receipt.png --text total
```

```json
{"height":200,"level":"accurate","matches":[{"center":{"x":404,"y":149},"confidence":1,"frame":{"height":45.4,"width":208.7,"x":299.7,"y":126.3},"match":{"center":{"x":347.3,"y":149.9},"frame":{"height":43.5,"width":95.2,"x":299.7,"y":128.2}},"text":"Total: 1,792"}],"mode":"background","path":"receipt.png","scale":1,"source":"image","text":"total","width":600}
```
