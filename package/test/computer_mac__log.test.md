# aux4 computer mac log

```afterAll
rm -rf log-test.jsonl log-test.jsonl.1 log-rotate.jsonl log-rotate.jsonl.1 log-state
```

## argument validation

### should reject an invalid limit

```execute
aux4 computer mac log --limit 0
```

```error
{"error":"Invalid --limit '0': use a positive number"}
```

## recording actions

### should record a failed input command with its error

```execute
rm -f log-test.jsonl; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac click --x 10 --y 20 --app ThisAppDoesNotExist12345 2>/dev/null; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac log --limit 5 | jq -c '.entries[] | {command, app, args, result, error, ts: (.ts | test("^20"))}'
```

```expect
{"command":"click","app":"ThisAppDoesNotExist12345","args":{"app":"ThisAppDoesNotExist12345","button":"left","count":"1","mode":"auto","x":"10","y":"20"},"result":"error","error":"App not running: ThisAppDoesNotExist12345","ts":true}
```

### should truncate typed text

```execute
AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac type --text "a long and private sentence typed by an agent" --app ThisAppDoesNotExist12345 2>/dev/null; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac log --limit 1 | jq -r '.entries[0].args.text'
```

```expect
a long and priva… (45 chars)
```

### should not record read-only commands

```execute
AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac find Save --app ThisAppDoesNotExist12345 2>/dev/null; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac log | jq -c '[.entries[].command]'
```

```expect
["click","type"]
```

### should not record dry runs

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac type --text hi --app TextEdit > /dev/null; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac log | jq '.entries | length'
```

```expect
2
```

### should show the most recent entries first-to-last up to --limit

```execute
AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-test.jsonl aux4 computer mac log --limit 1 | jq -c '[.entries[].command]'
```

```expect
["type"]
```

## rotation

### should rotate the file when it grows past its maximum and keep reading both

```execute
rm -f log-rotate.jsonl*; for i in 1 2 3 4; do AUX4_COMPUTER_MAC_LOG_MAX_BYTES=300 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-rotate.jsonl aux4 computer mac focus --app ThisAppDoesNotExist12345 2>/dev/null; done; test -f log-rotate.jsonl.1 && echo rotated; AUX4_COMPUTER_MAC_LOG_FILE=$PWD/log-rotate.jsonl aux4 computer mac log --limit 2 | jq -c '[.entries[].command]'
```

```expect
rotated
["focus","focus"]
```

## empty log

### should return no entries when nothing was recorded

```execute
AUX4_COMPUTER_MAC_LOG_FILE=$PWD/no-such-log.jsonl aux4 computer mac log | jq -c '{entries, stopped}'
```

```expect
{"entries":[],"stopped":false}
```

## the shared action log

```beforeEach
rm -rf log-state
```

### should record the provider name on every entry

```execute
AUX4_COMPUTER_STATE_DIR=$PWD/log-state aux4 computer mac click --x 10 --y 20 --app ThisAppDoesNotExist12345 2>/dev/null; AUX4_COMPUTER_STATE_DIR=$PWD/log-state aux4 computer mac log | jq -c '[.entries[] | {provider, command}]'
```

```expect
[{"provider":"mac","command":"click"}]
```

### should write actions.jsonl into AUX4_COMPUTER_STATE_DIR, readable by 'aux4 computer log', mode 0600

```execute
export AUX4_COMPUTER_STATE_DIR=$PWD/log-state; aux4 computer mac hide ThisAppDoesNotExist12345 2>/dev/null; aux4 computer log | jq -c '[.entries[] | {provider, command, app, result}]'; ls -l log-state/actions.jsonl | cut -c1-10
```

```expect
[{"provider":"mac","command":"hide","app":"ThisAppDoesNotExist12345","result":"error"}]
-rw-------
```
