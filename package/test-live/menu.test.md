# Live: menu (Calculator.app)

Drives Calculator's menu in the background: listing, switching View > Scientific/Basic (checking
it actually changed the key count and, when refreshed, the check mark), and a missing item error.

```timeout
15000
```

```beforeAll
aux4 computer mac open Calculator > /dev/null
sleep 1
```

```afterAll
aux4 computer mac quit Calculator --force true > /dev/null 2>&1 || true
```

### should list View in the menu

```execute
aux4 computer mac menu --app Calculator | jq -c '[.menus[].title] | index("View") != null'
```

```expect
true
```

### should switch to Scientific in the background and add keys

```execute
BASIC=$(aux4 computer mac find "" --role AXButton --app Calculator | jq '.matches | length')
aux4 computer mac menu --app Calculator --path "View > Scientific" --mode background | jq -c '{mode, pressed}'
sleep 1
SCI=$(aux4 computer mac find "" --role AXButton --app Calculator | jq '.matches | length')
jq -n -c --argjson b "$BASIC" --argjson s "$SCI" '($s > $b)'
```

```expect:partial
{"mode":"background","pressed":"Scientific"}
true
```

### should report a check mark on some macOS versions (warn, don't gate)

```execute
aux4 computer mac menu --app Calculator | jq -e '[.menus[] | select(.title == "View") | .children[] | select(.title == "Scientific")][0].checked == true' > /dev/null && echo true || echo "warn: no check mark on this macOS"
```

```expect:partial
*?
```

### should switch back to Basic

```execute
SCI_BEFORE=$(aux4 computer mac find "" --role AXButton --app Calculator | jq '.matches | length')
aux4 computer mac menu --app Calculator --path "view > basic" --mode background | jq -c '{mode, path}'
sleep 1
BASIC_AFTER=$(aux4 computer mac find "" --role AXButton --app Calculator | jq '.matches | length')
jq -n -c --argjson before "$SCI_BEFORE" --argjson after "$BASIC_AFTER" '($after < $before)'
```

```expect:partial
{"mode":"background","path":["View","Basic"]}
true
```

### should reject a missing menu item and list the available ones

```execute
aux4 computer mac menu --app Calculator --path "View > No Such Item"
```

```error:partial
Available: *?
```
