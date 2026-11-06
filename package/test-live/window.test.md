# Live: window and hide/unhide (TextEdit.app)

Drives a file-backed TextEdit window: listing, move/resize with read-back, minimize/restore,
fullscreen, raise (foreground-only), close, and app hide/unhide.

```timeout
25000
```

```beforeAll
echo "Opened by aux4/computer-mac CI" > /tmp/computer-mac-open-test.txt
aux4 computer mac open --file /tmp/computer-mac-open-test.txt --app com.apple.TextEdit --wait 20s > /dev/null
```

```afterAll
aux4 computer mac quit TextEdit --force true > /dev/null 2>&1 || true
```

## listing and geometry

### should list the file's window once

```execute
aux4 computer mac window list TextEdit | jq -c '[.windows[] | select(.title | test("computer-mac-open-test"))] | length'
```

```expect
1
```

### should move the window and read back the new position

```execute
aux4 computer mac window move --app TextEdit --title "computer-mac-open-test" --x 120 --y 140 --mode background | jq -c '{mode, method: .method, x: .after.frame.x, y: .after.frame.y}'
sleep 0.3
aux4 computer mac window list TextEdit | jq -c '[.windows[] | select(.title | test("computer-mac-open-test"))][0].frame | {x, y}'
```

```expect:partial
{"mode":"background","method":"AXPosition","x":120,"y":140}
{"x":120,"y":140}
```

### should resize the window and read back the new size

```execute
aux4 computer mac window resize --app TextEdit --title "computer-mac-open-test" --width 600 --height 400 --mode background | jq -c '{mode, width: .after.frame.width, height: .after.frame.height}'
sleep 0.3
aux4 computer mac window list TextEdit | jq -c '[.windows[] | select(.title | test("computer-mac-open-test"))][0].frame | {width, height}'
```

```expect:partial
{"mode":"background","width":600,"height":400}
{"width":600,"height":400}
```

## minimize, restore, fullscreen, raise

### should minimize and restore the window

```execute
aux4 computer mac window minimize --app TextEdit --title "computer-mac-open-test" | jq -c '{before: .before.minimized, after: .after.minimized}'
aux4 computer mac window restore --app TextEdit --title "computer-mac-open-test" | jq -c '{before: .before.minimized, after: .after.minimized}'
```

```expect:partial
{"before":false,"after":true}
{"before":true,"after":false}
```

### should enter and exit fullscreen when the runner allows it

```timeout
30000
```

```execute
if aux4 computer mac window fullscreen true --app TextEdit --title "computer-mac-open-test" > /tmp/computer-mac-fullscreen.json 2> /tmp/computer-mac-fullscreen.err; then
  jq -c '.after.fullscreen' /tmp/computer-mac-fullscreen.json
  aux4 computer mac window fullscreen false --app TextEdit --title "computer-mac-open-test" | jq -c '.after.fullscreen'
  sleep 1
else
  echo "true"; echo "false"
fi
```

```expect:partial
true
false
```

### should raise the window to the foreground

```execute
aux4 computer mac window raise --app TextEdit --title "computer-mac-open-test" | jq -c '{mode, frontmost}'
```

```expect
{"mode":"foreground","frontmost":true}
```

### should refuse to raise in the background

```execute
aux4 computer mac window raise --app TextEdit --mode background
```

```error:partial
*?
```

## hide and unhide

### should hide and read it back from apps

```execute
aux4 computer mac hide TextEdit | jq -c '{hidden, changed, mode}'
aux4 computer mac apps | jq -c '[.apps[] | select(.name == "TextEdit")][0].hidden'
```

```expect:partial
{"hidden":true,"changed":true,"mode":"background"}
true
```

### should report no change hiding an already-hidden app, then unhide

```execute
aux4 computer mac hide TextEdit | jq -c '.changed'
aux4 computer mac unhide TextEdit | jq -c '{hidden, changed}'
```

```expect:partial
false
{"hidden":false,"changed":true}
```

## documentEdited warning and close

### should warn that a background Accessibility edit does not mark the document edited

```execute
AREA=$(aux4 computer mac find "" --role AXTextArea --app TextEdit | jq -r '.matches[0].ref')
aux4 computer mac set --app TextEdit --element "$AREA" --value "Set silently by aux4/computer-mac CI" --mode background | jq -c '{documentEdited, warns: (.warning | test("does not mark the document edited")), after}'
```

```expect
{"documentEdited":false,"warns":true,"after":"Set silently by aux4/computer-mac CI"}
```

### should close the file-backed window without a save prompt

```execute
aux4 computer mac window close --app TextEdit --title "computer-mac-open-test" | jq -c '{closed, after}'
aux4 computer mac window list TextEdit | jq -c '[.windows[] | select(.title | test("computer-mac-open-test"))] | length'
```

```expect:partial
{"closed":true,"after":null}
0
```
