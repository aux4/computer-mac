macOS provider (`aux4 computer mac <command>`, the same commands as `aux4 computer <command>`). Actions go to the
app through Accessibility without moving the cursor or bringing the app forward wherever macOS allows it.

### Permissions (TCC)

- **Accessibility** is needed to read the accessibility tree and to act (click, type, menu, set, window...).
- **Screen Recording** is needed for `screenshot`, `ocr` and `screenshot --annotate`.
- Both are granted to the app that runs the command (the terminal, or the app hosting the agent), in System Settings >
  Privacy & Security; that app must be restarted afterwards. `aux4 computer permissions` shows the state with the
  exact shortcut to open the right settings pane. Never try to grant them yourself -- ask the person.

### What works in the background

Background (`mode: "background"`): pressing buttons and menu items (AXPress), setting values, checkboxes and pop-ups,
selecting text, inserting text at the caret, scrolling, reading, screenshots and OCR of covered windows, opening
apps/files without activating them, moving/resizing/minimizing/closing windows, hiding/unhiding, quitting.

Needs the foreground (auto falls back; `--mode background` errors): keystrokes and shortcuts to an app that isn't
frontmost, multi-clicks, drag, and the few controls that ignore Accessibility presses while in the background.

- **Editing menu items are disabled in the background**: Copy, Cut, Paste, Undo, Select All (and their shortcuts)
  only work on the frontmost app. Use `select --all true` / `select --text "…"` and `clipboard copy|paste --app` instead
  -- they work on the text element directly.
- `menu --path` presses other menu items (View, Format, File > New...) in the background.
- `focus` and `window raise` always activate the app (foreground).

### Silent data loss (documentEdited)

Text written through Accessibility (`set --value`, and `type` / `clipboard paste` in the background) does **not** mark
a macOS document as edited. Closing the window or quitting the app can then discard it **without a save prompt**.
When this applies, the result includes `"documentEdited": false` and a `"warning"`. Save explicitly
(`menu --app <App> --path "File > Save"`, or `shortcut cmd+s --app <App>` which falls back to the foreground) before
closing, or use `--mode foreground` so real keystrokes mark the document edited.

### OCR

- The first `ocr` (or `wait --source ocr`) after an install or a macOS update can take ~30s or time out: the system
  compiles its text-recognition model (Apple Neural Engine) on first use. Later calls take a fraction of a second.
- If it stays slow, ask the person to run `sudo killall ANECompilerService`, then retry.
- `--level fast` is quicker and less accurate; `--languages en-US,pt-BR` picks recognition languages.

### Coordinates and Retina

- Coordinates are screen points (not pixels), origin top-left of the main display; with `--app`, relative to the
  app's front window. On Retina displays one point is 2x2 pixels: screenshots report `scale`, and `image` boxes in
  `marks` are PNG pixels -- always click `center`/`windowCenter`, never image pixels.
- Displays left of or above the main one have negative coordinates: pass them with `=` (`--x=-200`).

### App names and labels

- `--app` takes the app's name (`Calculator`, `TextEdit`) or bundle id (`com.apple.TextEdit`).
- Labels differ between macOS versions. Calculator on macOS 26+ labels keys "All Clear", "Multiply", "Equals" and
  shows "1,792"; older versions use "AC"/"clear", "×", "=" and "1792". Search with `find` (substring, case-insensitive)
  and match a list of candidates instead of hard-coding one label. Text matching in `wait` and `ocr --text` ignores
  commas, so `--text 1792` also matches "1,792".
- Refs are child-index paths (`0.0.3.1`) into the accessibility tree; a sheet is `--role AXSheet`.

### Stop switch and log on macOS

The shared state lives in `~/Library/Application Support/aux4-computer` (`STOP`, `actions.jsonl`). The stop file of
older computer-mac releases (`~/Library/Application Support/aux4-computer-mac/STOP`) and `AUX4_COMPUTER_MAC_STOP=1`
are still honoured. `aux4 computer stop` (or `aux4 computer mac stop`) stops every provider.
