# aux4 computer mac hide

## validating

### should error when the app is not running

```execute
aux4 computer mac hide ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

## dry run (never touches the app)

### should act in the background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac hide Finder | jq -c '{app, hidden, mode, dryRun}'
```

```expect
{"app":"Finder","hidden":true,"mode":"background","dryRun":true}
```

### should refuse while the stop switch is on

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/hide-stop.jsonl aux4 computer mac hide Finder 2>&1 | jq -c '{stopped, command}'; rm -f hide-stop.jsonl
```

```expect
{"stopped":true,"command":"hide"}
```

## without permissions

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac hide Finder
```

```error:partial
Accessibility permission not granted*?
```

