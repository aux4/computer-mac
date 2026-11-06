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
aux4 computer mac wait --text "zzq text that is never on screen 0451" --app Finder --source ax --timeout 3s 2>&1 | jq -c '{error, condition, timeout, seenAx: (.seen.ax | type), running: .seen.running}'
```

```expect
{"error":"Timed out after 3s waiting for text 'zzq text that is never on screen 0451' in Finder to appear","condition":{"app":"Finder","gone":false,"source":"ax","text":"zzq text that is never on screen 0451"},"timeout":3,"seenAx":"array","running":true}
```

### should treat an app that is not running as not showing the text

```execute
aux4 computer mac wait --text Save --app ThisAppDoesNotExist12345 --source ax --timeout 200ms 2>&1 | jq -c '{error, seen}'
```

```expect
{"error":"Timed out after 200ms waiting for text 'Save' in ThisAppDoesNotExist12345 to appear","seen":{"running":false,"window":false}}
```

## when text recognition or screen capture is slow

A first recognition pass can take a long time while the system loads its models, and a screen
capture can stall when several processes capture at once. `AUX4_COMPUTER_MAC_OCR_DELAY_MS` simulates
slow recognition and `AUX4_COMPUTER_MAC_CAPTURE_HANG=1` a capture that never completes.

### should still give up at the timeout when recognition is slow

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --timeout 1s 2>&1 | jq -c '{bounded: (.waited < 1.6), slow: (.seen.ocrPending == true or .seen.ocrUnavailable != null)}'
```

```expect
{"bounded":true,"slow":true}
```

### should still give up at the timeout when the capture never completes

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_CAPTURE_HANG=1 aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --timeout 1500ms 2>&1 | jq -c '{bounded: (.waited < 2), ocrUnavailable: .seen.ocrUnavailable}'
```

```expect
{"bounded":true,"ocrUnavailable":"screen capture did not respond"}
```

### with --source ocr and --gone should not count an unfinished check as gone

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --gone true --timeout 1s 2>&1 | jq -c '{error}'
```

```expect
{"error":"Timed out after 1s waiting for text 'zzq text that is never on screen 0451' to disappear"}
```

### with --gone in auto should return at once when accessibility has no match, even if recognition is slow

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac wait --text "zzq text that is never on screen 0451" --gone true --timeout 3s | jq -c '{matches, quick: (.waited < 1)}'
```

```expect
{"matches":[],"quick":true}
```

### with --gone in auto should return at once when the capture never completes

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_CAPTURE_HANG=1 aux4 computer mac wait --text "zzq text that is never on screen 0451" --gone true --timeout 3s | jq -c '{matches, quick: (.waited < 1)}'
```

```expect
{"matches":[],"quick":true}
```

## two waits reading the screen at the same time

### should both give up near their timeout with exit 1, never hang

Both start at once and compete for the screen and for text recognition, so on a busy machine each may
take a little longer than its 3s timeout to report; the check is that both stop on their own with exit
code 1, well before the test's own limit. Only their JSON lines are read: a busy runner may add system
log lines to their stderr.

```timeout
30000
```

```execute
{ aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --timeout 3s 2>&1; echo "{\"exit\":$?}"; } > wait-a.out & { aux4 computer mac wait --text "zzq text that is never on screen 0451" --source ocr --timeout 3s 2>&1; echo "{\"exit\":$?}"; } > wait-b.out & wait; cat wait-a.out wait-b.out | jq -R -s -c '[split("\n")[] | fromjson? | objects] | {waited: [.[] | select(has("waited")) | .waited >= 3 and .waited < 10], exits: [.[] | select(has("exit")) | .exit]}'; rm -f wait-a.out wait-b.out
```

```expect
{"waited":[true,true],"exits":[1,1]}
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
