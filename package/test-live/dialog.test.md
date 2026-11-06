# Live: dialog, open --file and quit (TextEdit.app)

Drives TextEdit's save sheet: closing/quitting with an unsaved document blocks on a dialog, the
dialog's shape and press (Delete/Don't Save), opening a file given by bundle id and waiting for
its window, and a force-quit refusal on a session app (Finder).

```timeout
20000
```

```beforeAll
aux4 computer mac open TextEdit > /dev/null
aux4 computer mac wait --app TextEdit --timeout 20s > /dev/null
sleep 1
```

```afterAll
aux4 computer mac quit TextEdit --force true > /dev/null 2>&1 || true
```

## close with an unsaved document

### should report no dialog yet

```execute
aux4 computer mac dialog --app TextEdit | jq -c '.dialog'
```

```expect
null
```

### should open the save sheet when closing the untitled unsaved document

```timeout
15000
```

```execute
aux4 computer mac type "Unsaved by aux4/computer-mac CI" --app TextEdit --mode foreground > /dev/null
aux4 computer mac wait --app TextEdit --text "Unsaved by aux4/computer-mac CI" --source ax --timeout 10s > /dev/null
CLOSE=$(aux4 computer mac state --app TextEdit | jq -r '[.elements[] | select(.subrole == "AXCloseButton")][0].ref // empty')
if [ -n "$CLOSE" ]; then
  aux4 computer mac click --element "$CLOSE" --app TextEdit --mode background > /dev/null
else
  aux4 computer mac menu --app TextEdit --path "File > Close" > /dev/null
fi
for i in $(seq 1 25); do
  aux4 computer mac dialog --app TextEdit > /tmp/computer-mac-dialog.json
  jq -e '.dialog != null' /tmp/computer-mac-dialog.json > /dev/null && break
  sleep 0.2
done
jq -c '{isSheetOrPanel: (.dialog.kind == "sheet" or .dialog.kind == "save-panel"), hasText: (.dialog.text | length > 0)}' /tmp/computer-mac-dialog.json
```

```expect
{"isSheetOrPanel":true,"hasText":true}
```

### should press Delete / Don't Save and close the sheet

```execute
BUTTON=$(jq -r '[.dialog.buttons[].title | select(test("^(Delete|Don.t Save)$"))][0] // empty' /tmp/computer-mac-dialog.json)
aux4 computer mac dialog --app TextEdit --press "$BUTTON" --mode background | jq -c --arg b "$BUTTON" '{closed, mode, pressed: (.pressed == $b)}'
aux4 computer mac dialog --app TextEdit | jq -c '.dialog'
```

```expect:partial
{"closed":true,"mode":"background","pressed":true}
null
```

## save panel field labels

NSSavePanel reports its name field and "File Format" pop-up with an empty AXTitle/AXDescription --
the label an agent needs comes from the nearby "Save As:" / "File Format:" static text instead
(see axLabel's fallback in axhelpers.swift). Covers 'dialog' here; 'state' and 'find' share the
same describeElement/axLabel path so they get the same fallback.

### should open the real Save panel and label the name field and format pop-up

```timeout
20000
```

```execute
aux4 computer mac menu --app TextEdit --path "File > New" > /dev/null
for i in $(seq 1 25); do
  [ "$(aux4 computer mac window list TextEdit | jq '[.windows[] | select(.subrole == null)] | length')" -gt 0 ] && break
  sleep 0.2
done
aux4 computer mac type "Save panel label test" --app TextEdit --mode foreground > /dev/null
aux4 computer mac wait --app TextEdit --text "Save panel label test" --source ax --timeout 10s > /dev/null
aux4 computer mac shortcut cmd+s --app TextEdit > /dev/null
for i in $(seq 1 25); do
  aux4 computer mac dialog --app TextEdit > /tmp/computer-mac-save-panel.json
  jq -e '.dialog != null' /tmp/computer-mac-save-panel.json > /dev/null && break
  sleep 0.2
done
jq -c '{nameFieldLabel: ([.dialog.fields[] | select(.role == "AXTextField") | .label][0] // ""), formatLabel: ([.dialog.fields[] | select(.role == "AXPopUpButton" and ((.value // "") | test("Text Document|Rich Text"))) | .label][0] // "")}' /tmp/computer-mac-save-panel.json
```

```expect:partial
{"nameFieldLabel":"Save As*?","formatLabel":"File Format*?"}
```

### should cancel the save panel and discard the untitled document

```timeout
15000
```

```execute
aux4 computer mac dialog --app TextEdit --press Cancel --mode background | jq -c '{closed, pressed}'
aux4 computer mac menu --app TextEdit --path "File > Close" > /dev/null
for i in $(seq 1 25); do
  aux4 computer mac dialog --app TextEdit > /tmp/computer-mac-save-panel-close.json
  jq -e '.dialog != null' /tmp/computer-mac-save-panel-close.json > /dev/null && break
  sleep 0.2
done
BUTTON=$(jq -r '[.dialog.buttons[].title | select(test("^(Delete|Don.t Save)$"))][0] // empty' /tmp/computer-mac-save-panel-close.json)
aux4 computer mac dialog --app TextEdit --press "$BUTTON" --mode background | jq -c --arg b "$BUTTON" '{closed: true, pressed: (.pressed == $b)}'
```

```expect:partial
{"closed":true,"pressed":"Cancel"}
{"closed":true,"pressed":true}
```

## open --file by bundle id

### should open a file and wait for its window

```timeout
25000
```

```execute
echo "Opened by aux4/computer-mac CI" > /tmp/computer-mac-dialog-open-test.txt
aux4 computer mac open --file /tmp/computer-mac-dialog-open-test.txt --app com.apple.TextEdit --wait 20s | jq -c '{hasFrame: (.window.frame.width > 0), hasTitle: (.window.title | test("computer-mac-dialog-open-test")), bundleId: (.bundleId == "com.apple.TextEdit")}'
aux4 computer mac wait --app TextEdit --text "Opened by aux4/computer-mac CI" --source ax --timeout 10s | jq -c '.matches | length > 0'
```

```expect:partial
{"hasFrame":true,"hasTitle":true,"bundleId":true}
true
```

## quit with an unsaved document

### should be blocked by the unsaved-document sheet, then quit after Delete

```timeout
30000
```

```execute
aux4 computer mac menu --app TextEdit --path "File > New" > /dev/null
for i in $(seq 1 25); do
  [ "$(aux4 computer mac window list TextEdit | jq '[.windows[] | select(.subrole == null)] | length')" -gt 0 ] && break
  sleep 0.2
done
aux4 computer mac type "Unsaved by aux4/computer-mac CI" --app TextEdit --mode foreground | jq -c '.mode'
aux4 computer mac wait --app TextEdit --text "Unsaved by aux4/computer-mac CI" --source ax --timeout 10s > /dev/null
aux4 computer mac window close --app TextEdit > /tmp/computer-mac-close-unsaved.json 2>&1 || true
jq -c '{closed, hasDialog: (.dialog != null), noted: (.note | test("dialog --app"))}' /tmp/computer-mac-close-unsaved.json
aux4 computer mac quit TextEdit --timeout 10s > /tmp/computer-mac-quit-blocked.json 2>&1 || true
jq -c '{terminated, hasButtons: (.dialog.buttons | length > 0), noted: (.note | test("dialog --app"))}' /tmp/computer-mac-quit-blocked.json
BUTTON=$(jq -r '[.dialog.buttons[].title | select(test("^(Delete|Don.t Save)$"))][0] // empty' /tmp/computer-mac-quit-blocked.json)
aux4 computer mac dialog --app TextEdit --press "$BUTTON" --mode background | jq -c --arg b "$BUTTON" '{closed, pressed: (.pressed == $b)}'
```

```expect:partial
"foreground"
{"closed":false,"hasDialog":true,"noted":true}
{"terminated":false,"hasButtons":true,"noted":true}
{"closed":true,"pressed":true}
```

### should finish quitting and disappear from apps

```timeout
15000
```

```execute
sleep 0.5
aux4 computer mac quit TextEdit --timeout 10s > /dev/null 2>&1 || true
for i in $(seq 1 50); do
  [ "$(aux4 computer mac apps | jq '[.apps[] | select(.name == "TextEdit")] | length')" -eq 0 ] && break
  sleep 0.2
done
aux4 computer mac apps | jq -c '[.apps[] | select(.name == "TextEdit")] | length'
```

```expect
0
```

## session apps

### should refuse to force-quit Finder

```execute
aux4 computer mac quit Finder --force true
```

```error:partial
*?
```
