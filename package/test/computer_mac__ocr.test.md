# aux4 computer mac ocr

## recognizing an existing PNG

The fixture `fixtures/ocr-sample.png` is 600x200 and shows "Hello aux4" near the top left and
"Total: 1,792" near the bottom right.

### should return every line of text in reading order

The first recognition by a new build can take about 30s on a Mac with a Neural Engine while macOS
prepares its text models; later ones take a fraction of a second.

```timeout
90000
```

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png | jq -c '[.matches[].text]'
```

```expect
["Hello aux4","Total: 1,792"]
```

### should describe the source image

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png | jq -c '{source, width, height, scale, level, mode}'
```

```expect:json
{
  "source": "image",
  "width": 600,
  "height": 200,
  "scale": 1,
  "level": "accurate",
  "mode": "background"
}
```

### should give each line a top-left based frame and center

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png | jq '.matches[0] as $a | .matches[1] as $b | ($a.center.x > 100 and $a.center.x < 180 and $a.center.y > 35 and $a.center.y < 75) and ($b.center.x > 360 and $b.center.x < 450 and $b.center.y > 125 and $b.center.y < 170) and ($a.frame.x > 30 and $a.frame.x < 55 and $a.frame.width > 150) and ($a.confidence > 0.3)'
```

```expect
true
```

### should not need the Screen Recording permission

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac ocr --image fixtures/ocr-sample.png | jq -c '[.matches[].text]'
```

```expect
["Hello aux4","Total: 1,792"]
```

### should convert pixels to points with --scale

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --scale 2 | jq '.width == 300 and .height == 100 and .scale == 2 and .matches[0].center.x > 50 and .matches[0].center.x < 90'
```

```expect
true
```

## filtering with --text

### should only return lines containing the text, case-insensitively

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --text HELLO | jq -c '{text, matches: [.matches[].text]}'
```

```expect
{"text":"HELLO","matches":["Hello aux4"]}
```

### should locate just the matched text inside the line

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --text "1,792" | jq '.matches[0] as $l | ($l.match.center.x > $l.center.x) and ($l.match.frame.width < $l.frame.width) and ($l.match.frame.x >= $l.frame.x)'
```

```expect
true
```

### should ignore commas and whitespace, so 1792 matches 1,792

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --text "1792" | jq -c '[.matches[] | {text, hasMatch: (.match != null)}]'
```

```expect
[{"text":"Total: 1,792","hasMatch":true}]
```

### should return an empty matches array when nothing matches

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --text "not on the image" | jq -c '.matches'
```

```expect
[]
```

## errors

### should error when the image does not exist

```execute
aux4 computer mac ocr --image fixtures/does-not-exist.png
```

```error
{"error":"Image not found: fixtures/does-not-exist.png"}
```

### should error on an unknown recognition level

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --level slow
```

```error
{"error":"Invalid --level 'slow': use accurate or fast"}
```

### should error on an unsupported language

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --languages xx-YY
```

```error:partial
Unsupported OCR language 'xx-YY'*?
```

### should refuse --app together with --image

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --app Calculator
```

```error
{"error":"Use either --app or --image, not both"}
```

## capturing the screen without Screen Recording permission

### should error with guidance, never a silent empty result

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac ocr
```

```error:partial
Screen Recording permission not granted*?
```

## app not running

### should error clearly

```execute
aux4 computer mac ocr --app "ThisAppDoesNotExist12345"
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

## --timeout

`ocr` always stops at `--timeout` (default `60s`) with a JSON error on stderr and exit code `1`, whatever
is still in flight. `AUX4_COMPUTER_MAC_OCR_DELAY_MS` simulates slow recognition and
`AUX4_COMPUTER_MAC_CAPTURE_HANG=1` a screen capture that never completes.

### should finish normally well within the timeout

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --timeout 20s | jq -c '[.matches[].text]'
```

```expect
["Hello aux4","Total: 1,792"]
```

### should give up at the timeout when recognition is slow

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac ocr --image fixtures/ocr-sample.png --timeout 1s 2>&1 | jq -c '{error, phase, timeout, bounded: (.waited >= 1 and .waited < 1.6)}'
```

```expect
{"error":"Text recognition did not finish within 1s","phase":"recognition","timeout":1,"bounded":true}
```

### should exit with code 1 on timeout

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_OCR_DELAY_MS=5000 aux4 computer mac ocr --image fixtures/ocr-sample.png --timeout 500ms 2>/dev/null; echo "exit $?"
```

```expect
exit 1
```

### should give up at the timeout when the screen capture never completes

```timeout
8000
```

```execute
AUX4_COMPUTER_MAC_CAPTURE_HANG=1 aux4 computer mac ocr --timeout 2s 2>&1 | jq -c '{error, phase, bounded: (.waited < 2.6)}'
```

```expect
{"error":"Timed out after 2s during screen capture","phase":"capture","bounded":true}
```

### should report a stalled capture after 10s even with a longer timeout

```timeout
16000
```

```execute
AUX4_COMPUTER_MAC_CAPTURE_HANG=1 aux4 computer mac ocr --timeout 30s 2>&1 | jq -c .
```

```expect
{"error":"Screen capture did not respond within 10s","phase":"capture"}
```

### should reject a timeout that isn't a duration

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --timeout soon
```

```error
{"error":"Invalid --timeout 'soon': use e.g. 500ms, 10s or 2m"}
```

### should reject a zero timeout

```execute
aux4 computer mac ocr --image fixtures/ocr-sample.png --timeout 0s
```

```error
{"error":"Invalid --timeout '0s': must be more than 0"}
```
