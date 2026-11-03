# aux4 computer mac window move

## validating

### should require --x and --y

```execute
aux4 computer mac window move --app TextEdit --x 10
```

```error
{"error":"--x and --y are required (screen points of the window's top-left corner)"}
```

### should reject a non-number

```execute
aux4 computer mac window move --app TextEdit --x left --y 10
```

```error
{"error":"Invalid --x 'left': use a number"}
```

### should refuse --title together with --index

```execute
aux4 computer mac window move --app TextEdit --x 1 --y 2 --title Untitled --index 0
```

```error
{"error":"Give either --title or --index, not both"}
```

## moving (dry run, never touches the screen)

### should move in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window move --app TextEdit --x 100 --y 80
```

```expect:json
{
  "action": "move",
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background",
  "requested": {
    "x": 100,
    "y": 80
  }
}
```

### should accept a negative x with --x=

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window move --app TextEdit --x=-200 --y 80 | jq -c .requested
```

```expect
{"x":-200,"y":80}
```

### should report a fallback to the foreground when the background is not possible

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac window move --app TextEdit --x 1 --y 2 | jq -c '{mode, fallbackReason}'
```

```expect
{"mode":"foreground","fallbackReason":"background simulated as unavailable"}
```

## the stop switch

### should refuse to move and log the refusal as window move

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/window-move.jsonl aux4 computer mac window move --app TextEdit --x 1 --y 2 2>&1 | jq -c '{stopped, command}'; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/window-move.jsonl aux4 computer mac log | jq -c '[.entries[] | {command, args, result}]'; rm -f window-move.jsonl
```

```expect
{"stopped":true,"command":"window move"}
[{"command":"window move","args":{"action":"move","app":"TextEdit","mode":"auto","x":"1","y":"2"},"result":"error"}]
```

