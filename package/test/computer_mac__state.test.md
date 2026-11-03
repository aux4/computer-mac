# aux4 computer mac state

## argument validation

### should reject an invalid depth

```execute
aux4 computer mac state --depth abc
```

```error
{"error":"Invalid --depth 'abc': use 0 or more"}
```

### should reject an invalid limit

```execute
aux4 computer mac state --limit 0
```

```error
{"error":"Invalid --limit '0': use a positive number"}
```

### should error when the app is not running

```execute
aux4 computer mac state --app ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

## snapshot of Finder

### should describe the app, its windows, focus, dialog and elements

```execute
aux4 computer mac state --app Finder | jq -c '{name: .app.name, bundleId: .app.bundleId, hidden: (.app.hidden | type), frontmost: (.frontmost.pid | type), windows: (.windows | type), focused: has("focused"), dialog: has("dialog"), elements: (.elements | type), depth}'
```

```expect
{"name":"Finder","bundleId":"com.apple.finder","hidden":"boolean","frontmost":"number","windows":"array","focused":true,"dialog":true,"elements":"array","depth":3}
```

### should accept a bundle id for --app

```execute
aux4 computer mac state --app com.apple.finder --depth 0 | jq -c '{name: .app.name, elements}'
```

```expect
{"name":"Finder","elements":[]}
```

### should cap the elements and say so

```execute
aux4 computer mac state --app Finder --limit 1 | jq -c '{n: (.elements | length <= 1), noted: (if .truncated then (.note | test("showing 1 of")) else true end)}'
```

```expect
{"n":true,"noted":true}
```

### should work while the stop switch is on (read-only)

```execute
AUX4_COMPUTER_MAC_STOP=1 aux4 computer mac state --app Finder --depth 0 | jq -r .app.name
```

```expect
Finder
```

## without permissions

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac state
```

```error:partial
Accessibility permission not granted*?
```
