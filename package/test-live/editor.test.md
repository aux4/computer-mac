# Live: TextEdit (typing, select, set)

Drives TextEdit: waiting for its window, background typing with a concurrent `wait` catching the
text as it appears, select by all/text/range, a cmd+a shortcut, setting the text area's value
directly, and (when present) a pop-up/checkbox control. Also checks TextEdit's state shape.

```timeout
25000
```

```beforeAll
aux4 computer mac open TextEdit > /dev/null
aux4 computer mac wait --app TextEdit --timeout 20s > /dev/null
sleep 1
```

```afterAll
aux4 computer mac quit TextEdit --force true > /dev/null 2>&1 || true
```

## opening and typing

### should see TextEdit's window via wait --app

```execute
aux4 computer mac wait --app TextEdit --timeout 10s | jq -c '{source, hasMatches: (.matches | length > 0)}'
```

```expect
{"source":"app","hasMatches":true}
```

### should type in the background and have a concurrent wait catch the text

```timeout
15000
```

```execute
TEXT="Hello from aux4/computer-mac CI"
aux4 computer mac wait --app TextEdit --text "$TEXT" --timeout 10s > /tmp/computer-mac-wait-type.json 2> /tmp/computer-mac-wait-type.err &
WP=$!
sleep 1
aux4 computer mac type "$TEXT" --app TextEdit > /dev/null
WRC=0; wait "$WP" || WRC=$?
jq -c --argjson rc "$WRC" '{rc: $rc, waited: (.waited < 10), hasMatches: (.matches | length > 0)}' /tmp/computer-mac-wait-type.json
```

```expect
{"rc":0,"waited":true,"hasMatches":true}
```

### should find the typed text

```execute
aux4 computer mac find "Hello from aux4/computer-mac CI" --app TextEdit | jq -c '.matches | length > 0'
```

```expect
true
```

## select and shortcuts

### should select all with range start 0

```execute
aux4 computer mac select --app TextEdit --all true --mode background | jq -c '{mode, selected, start: .range.start}'
```

```expect
{"mode":"background","selected":"Hello from aux4/computer-mac CI","start":0}
```

### should copy the selection to the clipboard

```execute
aux4 computer mac clipboard copy --app TextEdit --mode background | jq -c '{mode, text}'
```

```expect
{"mode":"background","text":"Hello from aux4/computer-mac CI"}
```

### should select a word by text

```execute
aux4 computer mac select --app TextEdit --text aux4 --mode background | jq -c '{selected, start: .range.start, length: .range.length}'
```

```expect
{"selected":"aux4","start":11,"length":4}
```

### should select a range by start/length

```execute
aux4 computer mac select --app TextEdit --start 0 --length 5 --mode background | jq -c '.selected'
```

```expect
"Hello"
```

### should select-all via the cmd+a shortcut

```execute
aux4 computer mac shortcut cmd+a --app TextEdit --mode background | jq -c '.mode'
```

```expect
"background"
```

## set

### should set the text area's value directly

```execute
AREA=$(aux4 computer mac find "" --role AXTextArea --app TextEdit | jq -r '.matches[0].ref')
aux4 computer mac set --app TextEdit --element "$AREA" --value "Set by aux4/computer-mac CI" --mode background | jq -c '{before, after, mode}'
```

```expect
{"before":"Hello from aux4/computer-mac CI","after":"Set by aux4/computer-mac CI","mode":"background"}
```

### should exercise a pop-up control if the window has one

```timeout
10000
```

```execute
POPUP=$(aux4 computer mac find "" --role AXPopUpButton --app TextEdit | jq -c '[.matches[] | select(.value != "")][0] // empty')
if [ -n "$POPUP" ]; then
  aux4 computer mac set --app TextEdit --element "$(echo "$POPUP" | jq -r .ref)" --option "$(echo "$POPUP" | jq -r .value)" | jq -c '.after == .before'
else
  echo "true"
fi
```

```expect
true
```

### should exercise a checkbox control if the window has one

```timeout
10000
```

```execute
BOX=$(aux4 computer mac find "" --role AXCheckBox --app TextEdit | jq -r '.matches[0].ref // empty')
if [ -n "$BOX" ]; then
  BEFORE=$(aux4 computer mac set --app TextEdit --element "$BOX" --checked true | tee /tmp/computer-mac-set-checked.json | jq -r .before)
  jq -e '.after == true' /tmp/computer-mac-set-checked.json > /dev/null
  aux4 computer mac set --app TextEdit --element "$BOX" --checked "$BEFORE" | jq -c --argjson b "$BEFORE" '.after == $b'
else
  echo "true"
fi
```

```expect
true
```

## state

### should report TextEdit's state with a text area

```execute
aux4 computer mac state --app com.apple.TextEdit | jq -c '{bundleId: (.app.bundleId == "com.apple.TextEdit"), hasTextArea: ([.elements[] | select(.role == "AXTextArea")] | length > 0)}'
```

```expect
{"bundleId":true,"hasTextArea":true}
```

## no document window (diagnose the real cause, never blame-the-background or blind keystrokes)

Closes every open document so only TextEdit's app chrome (no window, or an Open/Save panel with
no document window) is left. A `type` with nothing focused must error instead of sending real
keystrokes into nothing, and a disabled File menu item must say it's the missing document window,
not "in the background" (TextEdit is still frontmost here).

```timeout
20000
```

```beforeAll
# Close every open document through the app's own Accessibility tooling (no AppleScript/
# Automation permission needed, unlike osascript): press the close button, and if that opens
# a "keep this document?" sheet, press Delete/Don't Save, up to a few times.
for i in 1 2 3 4 5; do
  N=$(aux4 computer mac state --app TextEdit 2>/dev/null | jq -r '.windows | length // 0')
  [ "$N" = "0" ] && break
  CLOSE=$(aux4 computer mac state --app TextEdit 2>/dev/null | jq -r '[.windows[] | select(.ref != null)][0].ref // empty')
  if [ -n "$CLOSE" ]; then
    aux4 computer mac window close --app TextEdit > /dev/null 2>&1 || true
  fi
  for j in 1 2 3 4 5 6 7 8 9 10; do
    aux4 computer mac dialog --app TextEdit > /tmp/computer-mac-notype-dialog.json 2>/dev/null || echo '{}' > /tmp/computer-mac-notype-dialog.json
    jq -e '.dialog != null' /tmp/computer-mac-notype-dialog.json > /dev/null 2>&1 && break
    sleep 0.2
  done
  BUTTON=$(jq -r '[.dialog.buttons[].title | select(test("^(Delete|Don.t Save)$"))][0] // empty' /tmp/computer-mac-notype-dialog.json 2>/dev/null)
  if [ -n "$BUTTON" ]; then
    aux4 computer mac dialog --app TextEdit --press "$BUTTON" --mode background > /dev/null 2>&1 || true
  fi
  sleep 0.3
done
rm -f /tmp/computer-mac-notype-dialog.json
```

### should refuse to type with nothing focused instead of sending blind keystrokes

```execute
aux4 computer mac type "hello" --app TextEdit --mode auto
```

```error:partial
Nothing has keyboard focus in TextEdit*?
```

### should explain File > Save As is disabled because there is no document, not the background

```execute
aux4 computer mac menu --app TextEdit --path "File > Save As…"
```

```error:partial
Could not press the menu item: menu item 'File > Save As…' is disabled: TextEdit has no*
```
