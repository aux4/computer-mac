# aux4 computer mac quit

## validating

### should error when the app is not running

```execute
aux4 computer mac quit ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

### should refuse to force-quit Finder

```execute
aux4 computer mac quit Finder --force true
```

```error
{"error":"Refusing to force-quit Finder: use 'quit --app Finder' without --force (it relaunches), or leave it running"}
```

### should refuse to quit the Dock

```execute
aux4 computer mac quit Dock
```

```error
{"error":"Refusing to quit Dock (com.apple.dock): macOS needs it to keep the session working"}
```

### should reject an invalid --timeout

```execute
aux4 computer mac quit Finder --timeout soon
```

```error:partial
{"error":"Invalid --timeout*?
```

## quitting (dry run, never touches the app)

### should quit with terminate in the background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac quit Finder | jq -c '{app, bundleId, method, force, mode, dryRun}'
```

```expect
{"app":"Finder","bundleId":"com.apple.finder","method":"terminate","force":false,"mode":"background","dryRun":true}
```

## the stop switch

### should refuse to quit while stopped

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/quit-stop.jsonl aux4 computer mac quit Finder 2>&1 | jq -c '{stopped, command}'; rm -f quit-stop.jsonl
```

```expect
{"stopped":true,"command":"quit"}
```

