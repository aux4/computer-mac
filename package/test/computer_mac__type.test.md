# aux4 computer mac type

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac type "hello"
```

```error:partial
Accessibility permission not granted*?
```

## mode decision (dry run, never touches the screen)

### should type in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac type "hello" --app TextEdit
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background",
  "typed": 5
}
```

### should report a fallback when background isn't possible

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac type "hello"
```

```expect:json
{
  "dryRun": true,
  "fallbackReason": "background simulated as unavailable",
  "mode": "foreground",
  "typed": 5
}
```

## silent data-loss warning (document window, background type)

### should warn that a background accessibility type does not mark the document edited

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_DOCUMENT_EDIT=1 aux4 computer mac type "hello" --app TextEdit
```

```expect:json
{
  "app": "TextEdit",
  "documentEdited": false,
  "dryRun": true,
  "mode": "background",
  "typed": 5,
  "warning": "This edit went through Accessibility, not real keystrokes: TextEdit does not mark the document edited, so closing the window now would discard it without asking. Save explicitly first (e.g. 'shortcut cmd+s --app TextEdit' or 'menu --path \"File > Save\" --app TextEdit'), or re-run with --mode foreground to type real keystrokes."
}
```
