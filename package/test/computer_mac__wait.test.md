# aux4 computer mac wait

## argument validation

### should error when there is nothing to wait for

```execute
aux4 computer mac wait
```

```error
{"error":"Nothing to wait for: give --text (optionally with --role), --role, or --app"}
```

### should error on an invalid timeout

```execute
aux4 computer mac wait --app Finder --timeout soon
```

```error
{"error":"Invalid --timeout 'soon': use e.g. 500ms, 10s or 2m"}
```

### should error on an invalid interval

```execute
aux4 computer mac wait --app Finder --interval 5x
```

```error
{"error":"Invalid --interval '5x': use e.g. 500ms, 10s or 2m"}
```

### should error on an unknown source

```execute
aux4 computer mac wait --text Save --source pixels
```

```error
{"error":"Invalid --source 'pixels': use auto, ax or ocr"}
```

### should refuse --role with --source ocr

```execute
aux4 computer mac wait --text Save --role AXButton --source ocr
```

```error
{"error":"--role needs the accessibility tree: use --source auto or ax with --role"}
```

### should error on an invalid --gone

```execute
aux4 computer mac wait --app Finder --gone maybe
```

```error
{"error":"Invalid --gone 'maybe': use true or false"}
```

## waiting for an app window

### should time out with exit 1 and a JSON error naming the condition

```execute
aux4 computer mac wait --app ThisAppDoesNotExist12345 --timeout 300ms --interval 100ms 2>&1 | jq -c '{error, condition, seen, timeout, waited: (.waited >= 0.3)}'
```

```expect
{"error":"Timed out after 300ms waiting for a window of ThisAppDoesNotExist12345 to appear","condition":{"app":"ThisAppDoesNotExist12345","gone":false,"source":"auto"},"seen":{"running":false,"window":false},"timeout":0.3,"waited":true}
```

### should exit with code 1 on timeout

```execute
aux4 computer mac wait --app ThisAppDoesNotExist12345 --timeout 100ms 2>/dev/null; echo "exit=$?"
```

```expect
exit=1
```

### should accept a timeout in seconds and wait at least that long

```execute
aux4 computer mac wait --app ThisAppDoesNotExist12345 --timeout 1s --interval 250ms 2>&1 | jq '.timeout == 1 and .waited >= 1 and .waited < 2'
```

```expect
true
```

### should accept a bare number of seconds

```execute
aux4 computer mac wait --app ThisAppDoesNotExist12345 --timeout 0.2 2>&1 | jq -c '{timeout}'
```

```expect
{"timeout":0.2}
```

### with --gone should return immediately when the app has no window

```execute
aux4 computer mac wait --app ThisAppDoesNotExist12345 --gone true | jq -c '{source, matches, quick: (.waited < 1)}'
```

```expect
{"source":"app","matches":[],"quick":true}
```

## waiting for text

### with --gone should return immediately for text that is not there

```execute
aux4 computer mac wait --text "zzq text that is never on screen 0451" --app Finder --source ax --gone true | jq -c '{source, matches, quick: (.waited < 2)}'
```

```expect
{"source":"ax","matches":[],"quick":true}
```

### should time out with what it saw

```execute
aux4 computer mac wait --text "zzq text that is never on screen 0451" --app Finder --source ax --timeout 400ms 2>&1 | jq -c '{error, condition, timeout, seenAx: (.seen.ax | type), running: .seen.running}'
```

```expect
{"error":"Timed out after 400ms waiting for text 'zzq text that is never on screen 0451' in Finder to appear","condition":{"app":"Finder","gone":false,"source":"ax","text":"zzq text that is never on screen 0451"},"timeout":0.4,"seenAx":"array","running":true}
```

### should treat an app that is not running as not showing the text

```execute
aux4 computer mac wait --text Save --app ThisAppDoesNotExist12345 --source ax --timeout 200ms 2>&1 | jq -c '{error, seen}'
```

```expect
{"error":"Timed out after 200ms waiting for text 'Save' in ThisAppDoesNotExist12345 to appear","seen":{"running":false,"window":false}}
```

## when text recognition is slow

A first recognition pass can take a long time while the system loads its models;
`AUX4_COMPUTER_MAC_OCR_DELAY_MS` simulates that.

### should still give up at the timeout

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --timeout 1s 2>&1 | jq -c '{bounded: (.waited < 2.5), ocrPending: .seen.ocrPending}'
```

```expect
{"bounded":true,"ocrPending":true}
```

### with --gone should not count an unfinished check as gone

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --gone true --timeout 1s 2>&1 | jq -c '{error}'
```

```expect
{"error":"Timed out after 1s waiting for text 'zzq text that is never on screen 0451' to disappear"}
```

## without permissions

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac wait --text Save
```

```error:partial
Accessibility permission not granted*?
```

### should error with guidance when Screen Recording is not granted for --source ocr

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac wait --text Save --source ocr
```

```error:partial
Screen Recording permission not granted*?
```

### should not need any permission to wait for an app window

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac wait --app ThisAppDoesNotExist12345 --gone true | jq -c '.matches'
```

```expect
[]
```
