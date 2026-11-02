# Using a Mac with aux4/computer-mac

Drive macOS apps in the background with `aux4 computer mac`: look (state, find, ocr, screenshot --annotate), act by ref, wait.

Every command prints one JSON object on stdout (errors: JSON on stderr, exit code 1). The person is using this Mac:
actions go to the app through Accessibility without moving their cursor or bringing the app forward. Check `mode` in
each result.

## The loop

1. **State** -- `aux4 computer mac state --app <App>`: app, windows, focused element, open dialog and a compact tree of
   controls, each with a `ref`. Start here, and re-read after anything that changes the UI.
2. **Find** -- `aux4 computer mac find "<text>" --app <App> [--role AXButton]`: elements whose label or value contains
   the text, with `ref`, `frame`, `center` and `windowCenter`.
3. **OCR fallback** -- when the text isn't in the accessibility tree (canvas, web content, images):
   `aux4 computer mac ocr --app <App> --text "<text>"` reads the window's pixels; use the match's `windowCenter`.
4. **Look** -- when you need to see the layout: `aux4 computer mac screenshot --app <App> --annotate true` draws a
   numbered box on each actionable element and returns `marks: [{n, ref, role, label, frame, center, windowCenter,
   image}]`. Look at the image, pick a number, act on that mark's `ref`. `--roles all` also marks text and images.
5. **Act** -- prefer, in order:
   - `click --element <ref> --app <App>` (presses the element; no coordinates)
   - `menu --app <App> --path "File > Save As…"` (app menu items; editing items like Copy, Undo, Select All are
     disabled while the app is in the background -- use `select` and `clipboard` for those)
   - `set --app <App> --element <ref> --value "…"` / `--checked true` / `--option "…"` (fields, checkboxes, pop-ups)
   - `select --app <App> --all true` / `--text "…"`, then `clipboard copy`
   - `type "…" --app <App>` (inserts at the caret), `dialog --app <App> --press "Don't Save"`
   - `window move|resize|minimize|restore|close --app <App>`, `hide`/`unhide --app <App>`, `quit --app <App>`
   - last resort: `click --x --y --app <App>` (window coordinates), `shortcut cmd+k --app <App>`
6. **Wait** -- don't sleep and hope: `aux4 computer mac wait --app <App> --text "Saved" --timeout 10s` (or `--gone true`
   for something to disappear, `--role AXSheet` for a sheet). Then go back to 1.

Refs are child-index paths (`0.0.3.1`); they shift when the UI changes (a new window, a sheet). Re-read before acting
on an old ref.

## Background and its limits

Background (`mode: "background"`) works for: pressing buttons and menu items, setting values/checkboxes/pop-ups,
selecting text, inserting text, scrolling, reading, screenshots of covered windows, opening apps/files without
activating them, moving/resizing/minimizing/closing windows, hiding/unhiding, quitting.

It does **not** work for: keystrokes and multi-clicks to an app that isn't frontmost, drag, some controls that ignore
Accessibility presses while in the background. With the default `--mode auto` those **fall back to the foreground**:
the app is brought forward for a moment, real input is sent, then the cursor and frontmost app are put back. The
result says `mode: "foreground"`, a `fallbackReason` and `restored`. Use `--mode background` to get an error instead of
a fallback; `--mode foreground` to force real input. `focus` and `window raise` are always foreground.

## Coordinates

- Screen points, origin top-left of the main display; with `--app`, `--x/--y` are relative to the app's front window
  (the same space as `screenshot --app` and every `windowCenter`).
- `screenshot` images may be scaled: `image` boxes in `marks` are pixels of the PNG; `center`/`windowCenter` are
  points. Never pass image pixels to `click`.
- Negative values need `=`: `--x=-200`.

## Safety

- `aux4 computer mac stop` turns on the stop switch: every input/state command is refused until
  `aux4 computer mac resume`. Read-only commands keep working. Respect it; never resume on your own.
- `aux4 computer mac log` lists what was done (command, app, mode, result).
- Don't quit, close or move the person's windows unless asked. `quit` reports a "save changes?" dialog instead of
  quitting; answer it with `dialog --press` only as the person wants. `quit --force true` loses unsaved work.

## Permissions

`aux4 computer mac permissions` shows Accessibility (needed to read and act) and Screen Recording (screenshot, ocr).
Grant them to the terminal app in System Settings > Privacy & Security, then restart that terminal.

## Troubleshooting

- `Element not found for ref` -- the UI changed: run `state` or `find` again.
- An action did nothing -- check the result's `mode`/`method`, then verify with `state`/`wait`; never repeat a press
  blindly (a toggle flips back).
- `ocr` takes ~30s once, or times out -- the system compiles its text-recognition model on first use (after an
  install or OS update); later calls take a fraction of a second. If it stays slow, ask the person to run
  `sudo killall ANECompilerService`.
- Nothing visible to annotate -- the app has no on-screen window (hidden or minimized): `unhide` or
  `window restore` first.
