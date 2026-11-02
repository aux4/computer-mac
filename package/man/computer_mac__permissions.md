#### Description

Reports whether this terminal/app has been granted the two macOS privacy permissions
`computer mac` needs:

- **Accessibility** — required for `read`, `find`, `click`, `move`, `drag`, `type`, `shortcut`, `scroll`
  and `focus`.
- **Screen Recording** — required for `screenshot`.

Each permission returns `granted` plus a `guidance` string with the exact System Settings pane to open,
including a one-line `open "x-apple.systempreferences:..."` shortcut command. Run this first — every other
command fails fast with the same guidance if the permission it needs is missing, rather than silently
doing nothing.

#### Usage

```bash
aux4 computer mac permissions
```

#### Example

```bash
aux4 computer mac permissions
```

```json
{
  "accessibility": {
    "granted": false,
    "guidance": "Open System Settings > Privacy & Security > Accessibility and enable this terminal/app. Shortcut: open \"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\""
  },
  "screenRecording": {
    "granted": true,
    "guidance": "Screen Recording access is granted."
  }
}
```
