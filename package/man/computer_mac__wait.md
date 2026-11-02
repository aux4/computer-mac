#### Description

Blocks until something shows up on screen, or until it is gone, and returns as soon as it does. Use it
after an action whose effect takes time (a calculation, a page or dialog loading, an app launching)
instead of sleeping for a guessed amount and checking again.

It checks for one condition:

- **`--text`** (optionally with **`--role`**) — an element or text containing that text. Each check reads
  the app's accessibility tree first, like `find`; if no element matches, it reads the app's window
  (or the main display without `--app`) with OCR, like `ocr`. Without `--app`, the accessibility tree of
  the frontmost app is used.
- **`--role`** alone — any element with that role (accessibility only).
- **`--app`** alone — the app is running **and** has an on-screen window. Needs no permission.

Text matching ignores case, whitespace and commas, so `--text 1792` matches `1,792` (and `1 792`), and
`--text "1,792"` matches `1792`. `ocr --text` matches the same way. `find` is a plain case-insensitive match.

- **`--gone true`** — the opposite: wait until the text, element or window is no longer there. A check
  that couldn't finish (the app stopped responding, or the window couldn't be captured) doesn't count
  as "gone".
- **`--source`** — `auto` (default) as above; `ax` only reads the accessibility tree; `ocr` only reads
  pixels (no `--role`). In `auto`, OCR is skipped when Screen Recording isn't granted (noted in `notes`).
- **`--timeout`** — how long to wait: `500ms`, `10s`, `2m`, or a number of seconds (default `10s`).
- **`--interval`** — the pause between checks (default `500ms`). Checks never overlap: an OCR check
  can take a few hundred milliseconds, and the next one starts an interval after it finishes.

`wait` only reads: it never moves the cursor, never brings an app forward, and only reads a window with
OCR while it is on screen (covered is fine; hidden or on another Space is not seen). It needs the
Accessibility permission for `ax`/`auto`, and Screen Recording for `--source ocr`.

**On success** (exit `0`) it prints `waited` (seconds), `source` (`ax`, `ocr`, or `app`), the `app` when
known, and `matches` — the same entries `find` (source `ax`), `ocr` (source `ocr`) or `windows`
(source `app`) return, ready for `click`. With `--gone`, `matches` is `[]` and `source` is what was
checked (`ax+ocr` when both were).

**On timeout** (exit `1`) it prints a JSON error on stderr with the `condition`, the `timeout`, how long it
`waited`, and what it `seen` on the last check: whether the app was `running` and had a `window`, and the
first texts from the accessibility tree (`ax`) and OCR (`ocr`) — or, with `--gone`, what was still
`present`. That tells an agent whether it is waiting for the wrong text, the wrong app, or simply too
little time.

#### Usage

```bash
aux4 computer mac wait [<text>] [--text <text>] [--role <AXRole>] [--app <name>] [--gone true] [--source auto|ax|ocr] [--timeout 10s] [--interval 500ms]
```

text        Text to wait for (positional or `--text`)
--role      Only elements with this accessibility role, e.g. `AXButton`
--app       App to watch; alone, wait for it to have an on-screen window (default: frontmost app / whole screen)
--gone      `true` to wait until it's no longer there (default: `false`)
--source    `auto` (default), `ax` or `ocr`
--timeout   How long to wait (default: `10s`)
--interval  Pause between checks (default: `500ms`)

#### Example

Wait for Calculator to show the result after pressing `=`:

```bash
aux4 computer mac wait --app Calculator --text 1792
```

```json
{"app":"Calculator","matches":[{"center":{"x":645,"y":511},"enabled":true,"focused":false,"frame":{"height":36,"width":206,"x":542,"y":493},"label":"Edit field","ref":"0.0.0.0.1.0.0.0.0.0","role":"AXStaticText","value":"1,792","windowCenter":{"x":183,"y":112}}],"source":"ax","waited":1.7}
```

Wait for an app to open a window:

```bash
aux4 computer mac wait --app TextEdit --timeout 30s
```

```json
{"app":"TextEdit","matches":[{"app":"TextEdit","frame":{"height":488,"width":586,"x":152,"y":73},"id":258,"pid":15584,"title":"Untitled.rtf"}],"source":"app","waited":0.01}
```

Wait for a spinner's text to go away:

```bash
aux4 computer mac wait --app Safari --text "Loading" --gone true --timeout 1m
```

When it times out:

```bash
aux4 computer mac wait --app Calculator --text 1793 --timeout 2s
```

```json
{"condition":{"app":"Calculator","gone":false,"source":"auto","text":"1793"},"error":"Timed out after 2s waiting for text '1793' in Calculator to appear","seen":{"ax":["Calculator","256 × 7","1,792","Delete","All Clear","Percent","Divide","7","8","9","Multiply"],"ocr":["256×7","1,792","AC","%","7","8","9"],"running":true,"window":true},"timeout":2,"waited":2.1}
```
