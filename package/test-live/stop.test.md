# Live: action log and the stop switch (Calculator.app)

Checks that prior live-test commands were recorded in the action log, then the stop switch:
input is refused while stopped, read-only commands keep working, and resume restores input.

```timeout
15000
```

```beforeAll
aux4 computer mac open Calculator > /dev/null
sleep 1
```

```afterAll
aux4 computer mac resume > /dev/null 2>&1 || true
aux4 computer mac quit Calculator --force true > /dev/null 2>&1 || true
```

## action log

### should have logged commands from earlier live tests

```execute
aux4 computer mac log --limit 200 | jq -c '[.entries[].command] as $c | {menu: ($c | index("menu") != null), select: ($c | index("select") != null), set: ($c | index("set") != null), dialog: ($c | index("dialog") != null), open: ($c | index("open") != null), windowMove: ($c | index("window move") != null), hide: ($c | index("hide") != null), unhide: ($c | index("unhide") != null), quit: ($c | index("quit") != null)}'
```

```expect
{"menu":true,"select":true,"set":true,"dialog":true,"open":true,"windowMove":true,"hide":true,"unhide":true,"quit":true}
```

## stop switch

### should stop and refuse further input

```execute
aux4 computer mac stop | jq -c '.stopped'
```

```expect
true
```

### should refuse a click while stopped

```execute
aux4 computer mac click --x 5 --y 5 --app Calculator
```

```error:partial
*?
```

### should still allow a read-only command while stopped

```execute
aux4 computer mac state --app Calculator --depth 0 | jq -c '.app.name'
```

```expect
"Calculator"
```

### should resume and allow input again

```execute
aux4 computer mac resume | jq -c '.stopped'
aux4 computer mac menu --app Calculator --path "View > Basic" --mode background | jq -c '.mode'
```

```expect:partial
false
"background"
```
