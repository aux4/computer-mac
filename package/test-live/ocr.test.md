# Live: OCR vs accessibility (Calculator.app)

Confirms OCR (pixels) and accessibility agree on where the 256 x 7 result is, and that clicking
at an OCR-reported point lands on the right accessibility element.

```timeout
20000
```

```beforeAll
aux4 computer mac open Calculator > /dev/null
sleep 1
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
for keys in "All Clear|Clear|AC|C" "2" "5" "6" "Multiply|multiply|×|*" "7" "Equals|equals|="; do press "$keys"; done
aux4 computer mac wait --app Calculator --text 1792 --timeout 10s > /dev/null
```

```afterAll
aux4 computer mac quit Calculator --force true > /dev/null 2>&1 || true
```

### should read the result via OCR too (1792 or grouped 1,792)

```execute
OCR=$(aux4 computer mac ocr --app Calculator --text "1,792")
echo "$OCR" | jq -e '.matches | length > 0' > /dev/null || OCR=$(aux4 computer mac ocr --app Calculator --text "1792")
echo "$OCR" > /tmp/computer-mac-ocr.json
echo "$OCR" | jq -c '.matches | length > 0'
```

```expect
true
```

### should have the OCR windowCenter of the result land inside its accessibility frame

```execute
RESULT=$(aux4 computer mac find "1,792" --app Calculator)
echo "$RESULT" | jq -e '.matches | length > 0' > /dev/null || RESULT=$(aux4 computer mac find "1792" --app Calculator)
ELEMENT=$(echo "$RESULT" | jq -c '[.matches[] | select(.frame != null and .windowCenter != null)][0]')
jq -c --argjson el "$ELEMENT" '
  ($el.center.x - $el.windowCenter.x) as $ox | ($el.center.y - $el.windowCenter.y) as $oy |
  .matches[0].windowCenter as $c |
  ($c.x >= ($el.frame.x - $ox) and $c.x <= ($el.frame.x - $ox + $el.frame.width) and
   $c.y >= ($el.frame.y - $oy) and $c.y <= ($el.frame.y - $oy + $el.frame.height))' /tmp/computer-mac-ocr.json
```

```expect
true
```

### should click the 7 key at its OCR-reported point and press the right control

```execute
KEY=$(aux4 computer mac ocr --app Calculator --text 7 | jq -c '[.matches[] | select(.text == "7")] | max_by(.windowCenter.y) | .windowCenter // empty')
aux4 computer mac click --app Calculator --x "$(echo "$KEY" | jq .x)" --y "$(echo "$KEY" | jq .y)" --mode background | jq -c '.element.label'
```

```expect
"7"
```
