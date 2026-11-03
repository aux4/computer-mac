# aux4 computer mac window fullscreen

## dry run (never touches the screen)

### should enter full screen by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window fullscreen --app TextEdit | jq -c '{action, mode, requested}'
```

```expect
{"action":"fullscreen","mode":"background","requested":{"fullscreen":true}}
```

### should leave full screen with false

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window fullscreen false --app TextEdit | jq -c .requested
```

```expect
{"fullscreen":false}
```

### should reject a value that is not true or false

```execute
aux4 computer mac window fullscreen maybe --app TextEdit
```

```error
{"error":"Invalid --enabled 'maybe': use true or false"}
```

