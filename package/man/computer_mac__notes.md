#### Description

Prints the macOS specifics an agent needs, as markdown. `aux4 ai skill computer prompt` (from `aux4/computer`) appends
it after the generic method when this Mac's provider is `mac`. It covers:

- **Permissions (TCC)** — Accessibility and Screen Recording, granted to the app running the command
- **What works in the background** — and what needs the foreground; editing menu items (Copy, Paste, Undo, Select
  All) are disabled while an app is in the background, so use `select` and `clipboard` instead
- **Silent data loss** — Accessibility text edits don't mark a document edited (`"documentEdited": false`)
- **OCR** — the ~30s first run while macOS compiles its recognition model, and `sudo killall ANECompilerService`
- **Coordinates and Retina** — points versus PNG pixels, negative coordinates on other displays
- **App names and labels** — label differences between macOS versions (Calculator's "Equals" vs "=")
- **Stop switch and log on macOS** — where the shared state lives

It only prints text.

#### Usage

```bash
aux4 computer mac notes
```

#### Example

```bash
aux4 computer mac notes | head -3
```

```text
macOS provider (`aux4 computer mac <command>`, the same commands as `aux4 computer <command>`). Actions go to the
app through Accessibility without moving the cursor or bringing the app forward wherever macOS allows it.

```
