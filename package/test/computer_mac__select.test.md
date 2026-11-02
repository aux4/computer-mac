# aux4 computer mac select

## argument validation

### should say what to select

```execute
aux4 computer mac select --app TextEdit
```

```error
{"error":"Say what to select: --all true, --text <text> [--occurrence N], or --start N --length N"}
```

### should take only one way of selecting

```execute
aux4 computer mac select --all true --text hello
```

```error
{"error":"Give only one of --all, --text, or --start/--length"}
```

### should reject a start that is not a number

```execute
aux4 computer mac select --start abc --length 2
```

```error:partial
Invalid --start *?
```

### should reject an invalid occurrence

```execute
aux4 computer mac select --text hello --occurrence 0
```

```error:partial
Invalid --occurrence '0'*?
```

### should reject an occurrence without text

```execute
aux4 computer mac select --start 0 --length 1 --occurrence 2
```

```error
{"error":"--occurrence goes with --text"}
```

### should reject an invalid --all

```execute
aux4 computer mac select --all yes
```

```error
{"error":"Invalid --all 'yes': use true or false"}
```

## mode decision (dry run, never touches the screen)

### should select in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac select --app TextEdit --all true
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background"
}
```

### should fall back to real input in auto when background is not possible

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac select --app TextEdit --text hello | jq -c '{mode, fallbackReason}'
```

```expect
{"mode":"foreground","fallbackReason":"background simulated as unavailable"}
```

## errors

### should error when the app is not running

```execute
aux4 computer mac select --app ThisAppDoesNotExist12345 --all true
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

### should refuse while the stop switch is on

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/select-stop.jsonl aux4 computer mac select --app TextEdit --all true 2>&1; rm -f select-stop.jsonl
```

```expect:partial
{"command":"select","error":"Stopped: *?
```

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac select --all true
```

```error:partial
Accessibility permission not granted*?
```
