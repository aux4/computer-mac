# aux4 computer mac menu

## argument validation

### should reject a path that is only a menu

```execute
aux4 computer mac menu --app Calculator --path File
```

```error
{"error":"Invalid --path 'File': give a menu item, not just a menu, e.g. 'File > ...'"}
```

### should reject an empty title in the path

```execute
aux4 computer mac menu --app Calculator --path "File > > Close"
```

```error
{"error":"Invalid --path 'File > > Close': separate menu titles with '>', e.g. 'Format > Font > Bold'"}
```

### should reject an invalid depth

```execute
aux4 computer mac menu --depth 0
```

```error
{"error":"Invalid --depth '0': use 1 (menu titles), 2 (their items) or more for submenus"}
```

### should error when the app is not running

```execute
aux4 computer mac menu --app ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

## pressing an item (dry run, never touches the screen)

### should press in the background by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac menu --app TextEdit --path "Format > Font > Bold"
```

```expect:json
{
  "app": "TextEdit",
  "dryRun": true,
  "mode": "background",
  "path": [
    "Format",
    "Font",
    "Bold"
  ]
}
```

### should fall back to real input when background is not possible

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac menu --app TextEdit --path "File > Close" | jq -c '{mode, fallbackReason}'
```

```expect
{"mode":"foreground","fallbackReason":"background simulated as unavailable"}
```

### should refuse to fall back with --mode background

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_SIMULATE_BACKGROUND=unavailable aux4 computer mac menu --app TextEdit --path "File > Close" --mode background
```

```error
{"error":"Background mode not possible for menu: background simulated as unavailable"}
```

## stop switch

### should refuse to press an item while stopped

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/menu-stop.jsonl aux4 computer mac menu --app TextEdit --path "File > Close" 2>&1; rm -f menu-stop.jsonl
```

```expect:partial
{"command":"menu","error":"Stopped: *?
```

### should still list the menu bar while stopped (read-only)

```execute
AUX4_COMPUTER_MAC_STOP=1 aux4 computer mac menu --app ThisAppDoesNotExist12345
```

```error
{"error":"App not running: ThisAppDoesNotExist12345"}
```

## the Finder menu bar

### should list menus with titles and items

```execute
aux4 computer mac menu --app Finder | jq -c '{app, depth, hasFile: ([.menus[].title] | index("File") != null), items: ([.menus[] | select(.title == "File") | .children[]] | length > 3)}'
```

```expect
{"app":"Finder","depth":2,"hasFile":true,"items":true}
```

### should list only the menu titles at depth 1

```execute
aux4 computer mac menu --app Finder --depth 1 | jq -c '[.menus[] | has("children")] | unique'
```

```expect
[false]
```

### should name the available items when a title doesn't match

```execute
aux4 computer mac menu --app Finder --path "File > No Such Item 0451" --mode background
```

```error:partial
No menu item 'No Such Item 0451' under 'File'. Available: *?
```

## without permissions

### should error with guidance when Accessibility is not granted

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac menu --app Finder
```

```error:partial
Accessibility permission not granted*?
```
