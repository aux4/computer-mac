# Release Notes

## 0.6.0

- `screenshot --annotate true`: numbered set-of-marks boxes on the window's (or the frontmost app's) actionable
  elements, with `marks` (`n`, `ref`, `role`, `label`, `frame`, `center`, `windowCenter`, `image` box in PNG pixels);
  `--roles all` also marks text, images and headings; `--limit` caps the count (reported as `truncated`).
- `window list|move|resize|minimize|restore|close|fullscreen|raise`: an app's windows by `--title`/`--index`
  through Accessibility, in the background (except `raise`), returning the window before and after; `close`
  reports a "save changes?" sheet as `dialog`.
- `quit` (with `--force`, `--timeout`): reports a save dialog instead of quitting; never force-quits Finder or
  quits session processes. `hide` / `unhide` without activating anything.
- New commands are recorded in the action log (`window move`, ...) and refused while the stop switch is on.
- AI skill `computer-mac` (`aux4 ai skill computer-mac prompt`): the method for agents using this package.

## 0.5.1

- `dialog --press` reports the title of the button it pressed (it was empty once the dialog closed).
- `dialog` reports a "keep this new document?" sheet with a Save As name field as `save-panel`.
- `set --checked` never repeats a press that didn't change the state (it could toggle a control back
  when the app acted on it without updating its state); in `auto` that case is retried with the app in front.
- The action log records `click`'s accessibility action as its `method`.

## 0.5.0

- `state`: one call with the frontmost app, the target app (pid, bundle id, hidden), its windows, the
  focused element, the open dialog and a compact, capped tree of its actionable and text elements.
- `menu`: list an app's menu bar as a tree (title, ref, checked, shortcut, enabled, children), or press an
  item by path (`--path 'Format > Font > Bold'`) in the background; unmatched titles list what's available.
- `select`: select text through Accessibility in the background (`--all true`, `--text` with
  `--occurrence`, or `--start`/`--length`), returning the selected text and range. `shortcut cmd+a --app`
  now selects all in the background the same way.
- `set`: set a text field/area or slider value, a checkbox state, or a pop-up/combo box/radio group option
  on an element by ref; returns the value before and after.
- `dialog`: detect an alert, sheet, dialog, system alert or save/open panel (kind, title, text, buttons with
  default/cancel flags, fields); `--press` a button by title.
- `open`: `--file` and `--url` (in `--app` or the default app), `--wait <timeout>` for the app's (or the
  file's) window with its frame, `--hidden true`; output includes pid and bundle id.
- `--app` accepts bundle ids (`com.apple.TextEdit`) everywhere.
- Action log: every input/state command appends a JSON line to
  `~/Library/Logs/aux4-computer-mac/actions.jsonl` (typed text truncated, rotated at 10MB); `log` shows the
  latest entries.
- Stop switch: `stop` / `resume`, or `AUX4_COMPUTER_MAC_STOP=1`; while on, every input/state command
  refuses with a clear error and read-only commands keep working.

## 0.4.4

- `ocr`/`wait` timeout notes say what to do when every call is slow (macOS's Neural Engine compiler
  is stuck: `sudo killall ANECompilerService` or a restart clears it). New README Troubleshooting
  section.

## 0.4.3

- `ocr --timeout` (default `60s`): `ocr` always stops at the deadline with exit code `1` and a JSON
  error naming the `phase` (`capture` or `recognition`), instead of hanging on a capture that never
  returns. A screen capture that doesn't respond within 10s fails on its own. If `ocr` had brought an
  app forward for the capture, it restores the previous frontmost app before exiting.
- Slow first recognition explained and recovered: on a Mac with a Neural Engine, macOS compiles its
  text models the first time a new build of the package recognizes text (about 30s, longer while its
  Neural Engine compiler is busy). A process that exits during that compile used to throw it away, so
  every short-deadline call started over and each took ~30s. Now, when `ocr` or `wait` reaches its
  deadline mid-compile, the error says so (`note` / `notes`) and one short-lived background helper
  finishes the compile (`"warmup":true` / `seen.ocrWarmup`), so the next call is fast (~0.1s).
  `AUX4_COMPUTER_MAC_NO_WARMUP=1` turns the helper off.
- `ocr` and `wait` deadlines fire on time (system timer coalescing had let a 60s deadline fire ~4s late).

## 0.4.2

- `wait` always stops at `--timeout`: a watchdog prints the timeout error even when something in flight
  never returns. Each screen capture is bounded too; a capture that stalls (seen with several
  capturing processes at once) is reported as `seen.ocrUnavailable` and OCR is skipped for the rest of
  that wait.
- `wait --gone` in `auto`: a complete accessibility check with no match counts as gone, so a slow or
  unavailable OCR pass no longer makes it time out; OCR still keeps the text present when it answers
  quickly and sees it.
- `wait` no longer busy-spins the CPU between checks.

## 0.4.1

- `wait`: text recognition runs off the main loop and is bounded per check, so a slow first recognition
  pass (tens of seconds while the system loads its models) can no longer hold `wait` far past
  `--timeout`; accessibility checks keep running meanwhile, and `seen.ocrPending` reports it. A check
  that couldn't finish never counts as `--gone`.

## 0.4.0

### `wait`: block until something appears (or is gone)

New `aux4 computer mac wait` returns as soon as a condition holds, instead of an agent sleeping and
re-checking:

- `--text` (optionally `--role`): an element or text appears. Each check reads the accessibility tree
  first, then the app's window (or the screen) with OCR if the tree has no match. `--source ax|ocr`
  forces one.
- `--app` alone: the app is running with an on-screen window.
- `--gone true`: wait until it's no longer there.
- `--timeout` (`500ms`, `10s`, `2m`; default `10s`) and `--interval` (default `500ms`; checks never overlap).
- Success prints `waited`, `source` (`ax`/`ocr`/`app`) and the same `matches` as `find`/`ocr`/`windows`.
  Timeout exits `1` with a JSON error naming the condition and what was seen on the last check.
- Read-only: never moves the cursor or brings an app forward.

### `ocr`

- `--text` also ignores commas, so `1792` matches `1,792` (and `1,792` matches `1792`), the same
  matching `wait` uses.

### Build

- The live UI publish gate starts `wait --app Calculator --text 1792` before pressing `=` and checks it
  returns well before its timeout; it also waits for text typed into TextEdit.

## 0.3.1

- `ocr` returns its results as `matches` (the same key as `find`) instead of `lines`; each entry keeps its
  `text`. No match is `"matches": []` with exit code `0`.
- Fix: on 1x (non-Retina) displays `ocr --app` and screen OCR reported positions at half their real
  values. Capture now happens at the display's own density and is upscaled for recognition.
- CI: the live gate also clicks Calculator's 7 key at the position `ocr` reports and checks that the
  7 button was pressed.

## 0.3.0

### `ocr`: read the text on screen

New `aux4 computer mac ocr` recognizes the text in pixels — the main display, an app's front window
(`--app`, even when covered), or an existing PNG (`--image`, no Screen Recording needed) — on this Mac,
with no network and nothing to download.

- Each recognized line has `text`, `confidence`, and a `frame`/`center` in screen points; with `--app` also a
  `windowCenter`, the coordinate space `click --app` uses, so an agent can click something it read.
- `--text` keeps only the lines containing that text (case-insensitive, whitespace-tolerant) and adds a
  `match` with the position of just that text.
- `--level accurate|fast` (default `accurate`), `--languages en-US,...`, `--mode auto|background|foreground`,
  `--scale` (pixels per point for `--image`).

### Output

- JSON output no longer escapes `/` (paths print as `/tmp/a.png`, not `\/tmp\/a.png`).

### Build

- The live UI publish gate also reads Calculator's 256×7 result with `ocr` and checks that its position
  falls inside the accessibility element's frame from `find`. The Calculator and TextEdit screenshots
  (and the OCR output) are kept as workflow artifacts.

## 0.2.0

### Background mode by default

Actions now run in the background by default, so an agent can work in an app while the person keeps
using the Mac: the mouse cursor doesn't move and the frontmost app doesn't change.

- New `--mode auto|background|foreground` on `click`, `type`, `shortcut`, `scroll`, `open`,
  `clipboard copy` and `clipboard paste` (default `auto`: background, falling back to real input only
  when the background isn't possible; `background` errors instead of falling back; `foreground` is the
  previous behavior).
- Every action's JSON output has `"mode":"background"` or `"mode":"foreground"`, plus `fallbackReason`
  and `restored` when `auto` fell back. After a fallback the cursor position and the previously frontmost
  app are restored.
- New `--app` on `type`, `shortcut`, `scroll`, `clipboard copy` and `clipboard paste`.
- `click` presses the target app's accessibility element at the point, even when its window is covered.
- `type` and `clipboard paste` insert text at the app's text cursor; `clipboard copy` reads its selection.
- `shortcut --app` presses the app's matching menu item; without `--app` it stays a system-wide shortcut.
- `scroll` moves the scroll area's scroll bar.
- `open` launches without activating the app and leaves an already-running app untouched.
- `focus`, `move` and `drag` are always foreground and say so.

### Coordinates with `--app`

With `--app`, `--x`/`--y` on `click` and `scroll` are relative to the app's front window — the same space
as `screenshot --app`. `screenshot --app` output now includes the window `frame`, and `find --app` adds a
`windowCenter` to each match. **Breaking:** before, `--app` on `click` only applied to `--element` and `--x`/`--y` were always screen points.

### Build

- Built, tested and published by GitHub Actions (`aux4/action@v1`) on a macOS runner;
  publishing is gated on `aux4 test run` passing and on a live UI test that drives
  Calculator and TextEdit in background mode on the runner.

### Fixes

- `screenshot --app` no longer crashes (exit 134, `CGS_REQUIRE_INIT` assertion); it captures the app's
  front window even when it's covered.
- The clipboard tests save and restore the clipboard, so running them doesn't overwrite what the user
  copied.

## 0.1.1

### Fixes

- `shortcut` now presses modifier keys as real key events, so system-wide hotkeys like
  `cmd+space` (Spotlight) work. Before, the modifiers were only attached to the key and
  macOS ignored the combo.
- Tests no longer depend on whether this Mac has granted Accessibility or Screen
  Recording: the missing-permission tests set `AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1`,
  and never send real input to the screen.
