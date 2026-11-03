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

## annotate

### should reject an invalid --annotate

```execute
aux4 computer mac screenshot --annotate maybe
```

```error
{"error":"Invalid --annotate 'maybe': use true or false"}
```

### should reject invalid --roles

```execute
aux4 computer mac screenshot --annotate true --roles buttons
```

```error
{"error":"Invalid --roles 'buttons': use actionable or all"}
```

### should reject a non-positive --limit

```execute
aux4 computer mac screenshot --annotate true --limit 0
```

```error
{"error":"Invalid --limit '0': use a positive number"}
```

### should need Accessibility to read the elements

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac screenshot --annotate true
```

```error:partial
Accessibility permission not granted*?
```

