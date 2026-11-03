# aux4 computer mac dialog

## detecting

### should error when the app is not running

```execute
aux4 computer mac dialog --app ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

### should report the app and a dialog field (null when none is open)

```execute
aux4 computer mac dialog --app Finder | jq -c '{app, dialog: (.dialog == null or (.dialog | has("kind") and has("buttons")))}'
```

```expect
{"app":"Finder","dialog":true}
```

## pressing a button (dry run, never touches the screen)

### should press in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac dialog --app TextEdit --press "Don't Save"
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background",
  "pressed": "Don't Save"
}
```

### should refuse to press while the stop switch is on

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/dialog-stop.jsonl aux4 computer mac dialog --app TextEdit --press OK 2>&1; rm -f dialog-stop.jsonl
```

```expect:partial
{"command":"dialog","error":"Stopped: *?
```

### should still detect while the stop switch is on (read-only)

```execute
AUX4_COMPUTER_MAC_STOP=1 aux4 computer mac dialog --app ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

## without permissions

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac dialog
```

```error:partial
Accessibility permission not granted*?
```
