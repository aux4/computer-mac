# aux4 computer mac clipboard paste

## without accessibility permission

### should error with guidance, never a silent no-op, even with --text given

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac clipboard paste --text "won't be pasted"
```

```error:partial
Accessibility permission not granted*?
```

## mode decision (dry run, never touches the screen)

### should paste in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac clipboard paste --text "hello" --app TextEdit
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background",
  "pasted": "hello"
}
```

### should report a fallback when background isn't possible

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac clipboard paste --text "hello"
```

```expect:json
{
  "dryRun": true,
  "fallbackReason": "background simulated as unavailable",
  "mode": "foreground",
  "pasted": "hello"
}
```

## silent data-loss warning (document window, background paste)

### should warn that a background accessibility paste does not mark the document edited

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_DOCUMENT_EDIT=1 aux4 computer mac clipboard paste --text "hello" --app TextEdit
```

```expect:json
{
  "app": "TextEdit",
  "documentEdited": false,
  "dryRun": true,
  "mode": "background",
  "pasted": "hello",
  "warning": "This edit went through Accessibility, not real keystrokes: TextEdit does not mark the document edited, so closing the window now would discard it without asking. Save explicitly first (e.g. 'shortcut cmd+s --app TextEdit' or 'menu --path \"File > Save\" --app TextEdit'), or re-run with --mode foreground to type real keystrokes."
}
```
