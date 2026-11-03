# Live: calculator (Calculator.app)

Drives Calculator through aux4 computer mac on a hosted macOS runner: permissions, opening the
app, background button presses, and the 256 x 7 result appearing (wait/find), plus a
single-window screenshot regression check and the state shape.

Calculator's AXButton labels differ by macOS version, so each key below lists its candidates
separated by `|`; the first one found is pressed.

## permissions

### should have Accessibility and Screen Recording granted on this runner

```execute
aux4 computer mac permissions | jq -c '.accessibility.granted and .screenRecording.granted'
```

```expect
true
```

## 256 x 7 in the background

```timeout
20000
```

```beforeAll
aux4 computer mac open Calculator > /dev/null
sleep 1
```

```afterAll
aux4 computer mac quit Calculator --force true > /dev/null 2>&1 || true
```

### should press AC 2 5 6 x 7 in the background and see 1792 before '=' is pressed

```timeout
15000
```

```execute
press() {
  local keys="$1" REF=""
  IFS='|' read -ra CANDIDATES <<< "$keys"
  for key in "${CANDIDATES[@]}"; do
    REF=$(aux4 computer mac find "$key" --role AXButton --app Calculator | jq -r --arg k "$key" '[.matches[] | select(.label == $k)][0].ref // .matches[0].ref // empty')
    [ -n "$REF" ] && break
  done
  aux4 computer mac click --element "$REF" --app Calculator > /dev/null
  sleep 0.3
}
for keys in "All Clear|Clear|AC|C" "2" "5" "6" "Multiply|multiply|×|*"; do press "$keys"; done
aux4 computer mac wait --app Calculator --text 1792 --timeout 10s > /tmp/computer-mac-wait-calc.json 2> /tmp/computer-mac-wait-calc.err &
WP=$!
sleep 1.5
press "7"
press "Equals|equals|="
WRC=0; wait "$WP" || WRC=$?
jq -c --argjson rc "$WRC" '{rc: $rc, waited: (.waited < 10 and .waited >= 1), hasMatches: (.matches | length > 0), source}' /tmp/computer-mac-wait-calc.json
```

```expect:partial
{"rc":0,"waited":true,"hasMatches":true,"source":*?}
```

### should not report the shown result as gone

```execute
aux4 computer mac wait --app Calculator --text 1792 --gone true --timeout 1s
```

```error:partial
*?
```

### should see the result via OCR too

```timeout
15000
```

```execute
aux4 computer mac wait --app Calculator --text 1792 --source ocr --timeout 10s | jq -c '{source, hasMatches: (.matches | length > 0)}'
```

```expect
{"source":"ocr","hasMatches":true}
```

### should find the result via accessibility (1792 or grouped 1,792)

```execute
R=$(aux4 computer mac find "1,792" --app Calculator)
echo "$R" | jq -e '.matches | length > 0' > /dev/null || R=$(aux4 computer mac find "1792" --app Calculator)
echo "$R" | jq -c '.matches | length > 0'
```

```expect
true
```

### should screenshot a single window without crashing

```execute
aux4 computer mac screenshot --app Calculator --output /tmp/computer-mac-calculator.png | jq -c '.width > 0'
```

```expect
true
```

## state

### should report Calculator's state shape

```execute
aux4 computer mac state --app Calculator | jq -c '{name: (.app.name == "Calculator"), pid: (.app.pid | type == "number"), windows: (.windows | length > 0), hasFocused: has("focused"), dialog, elements: (.elements | length > 0), frontmostPid: (.frontmost.pid | type == "number")}'
```

```expect
{"name":true,"pid":true,"windows":true,"hasFocused":true,"dialog":null,"elements":true,"frontmostPid":true}
```
