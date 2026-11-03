# aux4 computer mac stop

```afterAll
rm -rf stop-test.flag stop-test.jsonl stop-state
```

## the stop switch file

### should create the stop file

```execute
rm -f stop-test.flag; AUX4_COMPUTER_MAC_STOP_FILE=$PWD/stop-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/stop-test.jsonl aux4 computer mac stop | jq -c '{stopped, file: (.file | endswith("stop-test.flag"))}'; test -f stop-test.flag && echo exists
```

```expect
{"stopped":true,"file":true}
exists
```

### should refuse input commands while it exists

```execute
AUX4_COMPUTER_MAC_STOP_FILE=$PWD/stop-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/stop-test.jsonl aux4 computer mac click --x 1 --y 1 2>&1 | jq -c '{stopped, command, says: (.error | test("^Stopped: .*stop-test.flag exists.*aux4 computer mac resume"))}'
```

```expect
{"stopped":true,"command":"click","says":true}
```

### should exit with code 1 when refused

```execute
AUX4_COMPUTER_MAC_STOP_FILE=$PWD/stop-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/stop-test.jsonl aux4 computer mac type --text hi 2>/dev/null; echo "exit=$?"
```

```expect
exit=1
```

### should refuse even a dry run

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_STOP_FILE=$PWD/stop-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/stop-test.jsonl aux4 computer mac clipboard paste --app TextEdit 2>&1 | jq -c '{stopped, command}'
```

```expect
{"stopped":true,"command":"clipboard paste"}
```

### should record refusals in the action log

```execute
AUX4_COMPUTER_MAC_STOP_FILE=$PWD/stop-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/stop-test.jsonl aux4 computer mac log | jq -c '{stopped, commands: [.entries[].command], results: ([.entries[].result] | unique)}'
```

```expect
{"stopped":true,"commands":["stop","click","type","clipboard paste"],"results":["error","ok"]}
```

### should keep read-only commands working

```execute
AUX4_COMPUTER_MAC_STOP_FILE=$PWD/stop-test.flag aux4 computer mac screen | jq '.displays | type'
```

```expect
"array"
```

## the environment switch

### should refuse input with AUX4_COMPUTER_MAC_STOP=1

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/stop-test.jsonl aux4 computer mac shortcut cmd+c --app TextEdit 2>&1 | jq -c '{stopped, says: (.error | test("AUX4_COMPUTER_MAC_STOP=1 is set"))}'
```

```expect
{"stopped":true,"says":true}
```

### should refuse input with the shared AUX4_COMPUTER_STOP=1

```execute
AUX4_COMPUTER_STOP=1 AUX4_COMPUTER_STATE_DIR=$PWD/stop-state aux4 computer mac click --x 1 --y 1 2>&1 | jq -c '{stopped, says: (.error | test("AUX4_COMPUTER_STOP=1 is set"))}'
```

```expect
{"stopped":true,"says":true}
```

## the shared state directory

```beforeEach
rm -rf stop-state
```

### should write the STOP file into AUX4_COMPUTER_STATE_DIR only

```execute
AUX4_COMPUTER_STATE_DIR=$PWD/stop-state aux4 computer mac stop | jq -c '{stopped, files: (.files | map(sub(".*/"; "")))}'; test -f stop-state/STOP && echo STOP
```

```expect
{"stopped":true,"files":["STOP"]}
STOP
```

### should be stopped by 'aux4 computer stop' when called directly

```execute
export AUX4_COMPUTER_STATE_DIR=$PWD/stop-state; aux4 computer stop > /dev/null; aux4 computer mac click --x 1 --y 1 --app Calculator 2>&1 | jq -c '{stopped, command}'; aux4 computer mac click --x 1 --y 1 --app Calculator 2>/dev/null; echo "exit=$?"
```

```expect
{"stopped":true,"command":"click"}
exit=1
```

### should allow input again after 'aux4 computer resume'

```execute
export AUX4_COMPUTER_STATE_DIR=$PWD/stop-state; aux4 computer mac stop > /dev/null; aux4 computer resume > /dev/null; AUX4_COMPUTER_DRY_RUN=1 aux4 computer mac click --x 1 --y 1 | jq -c '{dryRun}'
```

```expect
{"dryRun":true}
```

### should log the refusal with the provider name for 'aux4 computer log'

```execute
export AUX4_COMPUTER_STATE_DIR=$PWD/stop-state; aux4 computer mac stop > /dev/null; aux4 computer mac type hi --app Calculator 2>/dev/null; aux4 computer log --limit 1 | jq -c '.entries[0] | {provider, command, result}'
```

```expect
{"provider":"mac","command":"type","result":"error"}
```

## the default location

### should use ~/Library/Application Support/aux4-computer for STOP and actions.jsonl

```execute
env -u AUX4_COMPUTER_STATE_DIR -u AUX4_COMPUTER_MAC_STOP_FILE -u AUX4_COMPUTER_MAC_LOG_FILE aux4 computer mac info | jq -c '{stop: (.stopFile | endswith("/Library/Application Support/aux4-computer/STOP")), log: (.logFile | endswith("/Library/Application Support/aux4-computer/actions.jsonl"))}'
```

```expect
{"stop":true,"log":true}
```
