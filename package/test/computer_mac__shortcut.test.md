# aux4 computer mac shortcut

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac shortcut "cmd+c"
```

```error:partial
Accessibility permission not granted*?
```

## mode decision (dry run, never touches the screen)

### should send the shortcut to an app in the background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac shortcut "cmd+a" --app TextEdit
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "keys": "cmd+a",
  "mode": "background"
}
```

### should press a system-wide shortcut as real input when no app is given

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac shortcut "cmd+space"
```

```expect:json
{
  "dryRun": true,
  "keys": "cmd+space",
  "mode": "foreground"
}
```

### should refuse --mode background for a system-wide shortcut

```execute
aux4 computer mac shortcut "cmd+space" --mode background
```

```error:partial
Background mode not possible for shortcut: without --app*?
```

## argument validation

### should reject an unknown key

```execute
aux4 computer mac shortcut "cmd+nosuchkey"
```

```error
{"error":"Unknown key: nosuchkey"}
```

### should reject an unknown modifier

```execute
aux4 computer mac shortcut "hyper+a"
```

```error
{"error":"Unknown modifier: hyper"}
```
