# aux4 computer mac set

## argument validation

### should require an element

```execute
aux4 computer mac set --value hello
```

```error
{"error":"--element is required: the element's ref from 'find' or 'state'"}
```

### should say what to set

```execute
aux4 computer mac set --element 0.1
```

```error
{"error":"Say what to set: --value <text|number>, --checked true|false, or --option <title>"}
```

### should take only one change

```execute
aux4 computer mac set --element 0.1 --value 5 --checked true
```

```error
{"error":"Give only one of --value, --checked, or --option"}
```

### should reject an invalid --checked

```execute
aux4 computer mac set --element 0.1 --checked maybe
```

```error
{"error":"Invalid --checked 'maybe': use true or false"}
```

## mode decision (dry run, never touches the screen)

### should set in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac set --app TextEdit --element 0.0.0 --value hello
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "element": {
    "ref": "0.0.0"
  },
  "mode": "background"
}
```

### should refuse to fall back with --mode background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac set --app TextEdit --element 0.0.0 --checked true --mode background
```

```error
{"error":"Background mode not possible for set: background simulated as unavailable"}
```

## errors

### should error when the app is not running

```execute
aux4 computer mac set --app ThisAppDoesNotExist12345 --element 0.1 --value 5
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

### should error on a ref that doesn't exist

```execute
aux4 computer mac set --app Finder --element 99.99.99 --value 5
```

```error
{"error":"Element not found for ref: 99.99.99"}
```

### should refuse while the stop switch is on

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/set-stop.jsonl aux4 computer mac set --app Finder --element 0.1 --value 5 2>&1; rm -f set-stop.jsonl
```

```expect:partial
{"command":"set","error":"Stopped: *?
```
