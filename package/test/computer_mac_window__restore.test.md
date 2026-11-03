# aux4 computer mac window restore

## dry run (never touches the screen)

### should restore in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window restore --app TextEdit --title Untitled
```

```expect:json
{
  "action": "restore",
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background"
}
```

### should error when the app is not running

```execute
aux4 computer mac window restore --app ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

### should refuse while the stop switch is on

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/window-restore.jsonl aux4 computer mac window restore --app TextEdit 2>&1 | jq -c '{stopped, command}'; rm -f window-restore.jsonl
```

```expect
{"stopped":true,"command":"window restore"}
```

