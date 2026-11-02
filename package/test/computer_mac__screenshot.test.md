# aux4 computer mac screenshot

## without screen recording permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac screenshot
```

```error:partial
Screen Recording permission not granted*?
```

## app not running

### should error clearly

```execute
aux4 computer mac screenshot --app "ThisAppDoesNotExist12345"
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```
