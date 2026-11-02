# aux4 computer mac window raise

## dry run (never touches the screen)

### should raise in the foreground (it is foreground by nature)

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window raise --app TextEdit
```

```expect:json
{
  "action": "raise",
  "app": "TextEdit",
  "dryRun": true,
  "mode": "foreground"
}
```

### should refuse --mode background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window raise --app TextEdit --mode background
```

```error
{"error":"Background mode not possible for window raise: raising a window brings its app to the front"}
```

