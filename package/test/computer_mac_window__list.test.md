# aux4 computer mac window list

## listing

### should error when the app is not running

```execute
aux4 computer mac window list ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

### should list Finder's windows with index, frame and state

```execute
aux4 computer mac window list Finder | jq -c '{app, windows: (.windows | type), shape: ([.windows[] | has("index") and has("frame") and has("minimized") and has("fullscreen")] | all)}'
```

```expect
{"app":"Finder","windows":"array","shape":true}
```

### should keep working while the stop switch is on (read-only)

```execute
AUX4_COMPUTER_MAC_STOP=1 aux4 computer mac window list Finder | jq -r .app
```

```expect
Finder
```

## without permissions

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac window list Finder
```

```error:partial
Accessibility permission not granted*?
```

