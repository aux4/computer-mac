# Live: screenshot --annotate (Calculator.app)

Checks the set-of-marks annotation: numbered marks in reading order, the 7 mark matching the 7
button's accessibility frame, the image box containing the windowCenter, --limit truncation, and
clicking a mark's ref presses the right button.

```timeout
15000
```

```beforeAll
aux4 computer mac open Calculator > /dev/null
sleep 1
mkdir -p /tmp/computer-mac-live-screenshots
```

```afterAll
aux4 computer mac quit Calculator --force true > /dev/null 2>&1 || true
```

### should annotate at least 10 numbered marks with full metadata

```execute
aux4 computer mac screenshot --app Calculator --annotate true --output /tmp/computer-mac-live-screenshots/calculator-annotated.png | tee /tmp/computer-mac-annotate.json | jq -c '{annotated, hasMarks: (.marks | length >= 10), numbered: ([.marks[].n] == [range(1; (.marks | length) + 1)]), complete: ([.marks[] | has("ref") and has("center") and has("windowCenter") and has("image")] | all)}'
```

```expect
{"annotated":true,"hasMarks":true,"numbered":true,"complete":true}
```

### should have the 7 mark match the 7 button's accessibility frame

```execute
MARK=$(jq -c '[.marks[] | select(.label == "7")][0]' /tmp/computer-mac-annotate.json)
SEVEN=$(aux4 computer mac find 7 --role AXButton --app Calculator | jq -c '[.matches[] | select(.label == "7")][0]')
jq -n -c --argjson m "$MARK" --argjson b "$SEVEN" '($m.ref == $b.ref) and ($m.center.x >= $b.frame.x and $m.center.x <= ($b.frame.x + $b.frame.width) and $m.center.y >= $b.frame.y and $m.center.y <= ($b.frame.y + $b.frame.height))'
```

```expect
true
```

### should have the 7 mark's image box contain its windowCenter

```execute
MARK=$(jq -c '[.marks[] | select(.label == "7")][0]' /tmp/computer-mac-annotate.json)
echo "$MARK" | jq -c '.scale as $k | ((.windowCenter.x * $k) >= .image.x and (.windowCenter.x * $k) <= (.image.x + .image.width) and (.windowCenter.y * $k) >= .image.y and (.windowCenter.y * $k) <= (.image.y + .image.height))'
```

```expect
true
```

### should truncate to --limit 3 marks and report it in --note

```execute
aux4 computer mac screenshot --app Calculator --annotate true --roles all --limit 3 | jq -c '{count: (.marks | length), truncated, noted: (.note | test("--limit 3"))}'
```

```expect
{"count":3,"truncated":true,"noted":true}
```

### should click the 7 mark's ref and press the 7 button

```execute
CLEAR=$(aux4 computer mac find clear --role AXButton --app Calculator | jq -r '.matches[0].ref // empty')
if [ -n "$CLEAR" ]; then aux4 computer mac click --element "$CLEAR" --app Calculator --mode background > /dev/null; sleep 0.3; fi
MARK=$(jq -c '[.marks[] | select(.label == "7")][0]' /tmp/computer-mac-annotate.json)
aux4 computer mac click --element "$(echo "$MARK" | jq -r .ref)" --app Calculator --mode background | jq -c '{mode, label: .element.label}'
```

```expect
{"mode":"background","label":"7"}
```

### should show 7 on the display after the click

```execute
sleep 0.3
aux4 computer mac find "" --role AXStaticText --app Calculator | jq -c '[.matches[] | select(.value == "7" or .label == "7")] | length > 0'
```

```expect
true
```
