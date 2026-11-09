#### Description

Types text, unicode-safe (emoji and non-ASCII included), into the focused element of the target app
(`--app`, or the frontmost app). Requires the Accessibility permission.

By default (`--mode auto`) typing happens **in the background**: the text is inserted at the app's text
cursor (replacing any selection, exactly like typing) through Accessibility, so the target app doesn't
need to be in front and nothing on screen moves. If the focused element doesn't accept that and the app is
already frontmost, the text is sent as keystrokes to that app only. Otherwise `auto` falls back to real
keystrokes: the app is brought forward, the text typed, and the previously frontmost app restored.
`--mode background` errors instead of falling back; `--mode foreground` always types real keystrokes at
the current focus.

The output's `mode` says which happened, and `method` how (`accessibility` or `postToPid`).

**Nothing focused, nothing typed:** if the app has **no focused element at all** (e.g. a fresh app with
only an Open panel and no document window, or a window where nothing is selected), `auto` and `background`
refuse and return an error — e.g. `Nothing has keyboard focus in TextEdit: it only has a panel: 'Open', no
document window. Open or create a document first (e.g. File > New), or click the field in the open panel.`
There is no field for the text to land in, so sending real keystrokes anyway would silently type into
nothing while still reporting a success-looking response. `--mode foreground` still types real keystrokes
as explicitly requested in this case, but the output carries a `"warning"` saying nothing is focused and
the keystrokes may not land anywhere — read it before assuming the text was entered.

Use `--delay` to wait before typing — useful right after opening a panel (e.g. Spotlight) that needs a
moment to receive focus.

**Silent data loss:** when `method` is `accessibility` and the focused element lives in a document window
(one with an `AXDocument`, i.e. backed by a file), macOS does not mark that window edited — unlike real
keystrokes, which do. The title bar shows no unsaved-changes dot and closing the window discards the typed
text with no "do you want to save?" prompt. In that case the output adds `"documentEdited": false` and a
`"warning"` telling you to save explicitly (`shortcut cmd+s --app <app>` or
`menu --path "File > Save" --app <app>`) or to re-run with `--mode foreground` so real keystrokes mark the
document edited. This doesn't apply to `method: postToPid`, which is already real keystrokes.

#### Usage

```bash
aux4 computer mac type <text> [--app <name>] [--delay <ms>] [--mode auto|background|foreground]
```

text      Text to type (positional)
--app     App to type into (default: the frontmost app)
--delay   Milliseconds to wait before typing (default: `0`)
--mode    `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac type "Hello, world!" --app TextEdit
```

```json
{"app":"TextEdit","method":"accessibility","mode":"background","typed":13}
```
