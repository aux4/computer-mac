# aux4 computer mac scroll

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac scroll --dy -100
```

```error:partial
Accessibility permission not granted*?
```

## mode decision (dry run, never touches the screen)

### should scroll in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac scroll --dy=-200 --app TextEdit
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "dx": 0,
  "dy": -200,
  "mode": "background"
}
```

### should error instead of falling back with --mode background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac scroll --dy=-200 --mode background
```

```error:partial
Background mode not possible for scroll*?
```
