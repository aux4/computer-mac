# aux4 computer mac open

## missing app argument

### should error clearly

```execute
aux4 computer mac open --app ""
```

```error:partial
--app is required
```

## mode decision (dry run, never touches the screen)

### should open without activating by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac open TextEdit
```

```expect:json
{
  "dryRun": true,
  "mode": "background",
  "opened": "TextEdit"
}
```

### should bring the app forward with --mode foreground

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac open TextEdit --mode foreground
```

```expect:json
{
  "dryRun": true,
  "mode": "foreground",
  "opened": "TextEdit"
}
```
