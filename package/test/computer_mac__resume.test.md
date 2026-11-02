# aux4 computer mac resume

```afterAll
rm -f resume-test.flag resume-test.jsonl
```

## after stop

### should remove the stop file and allow input again

```execute
AUX4_COMPUTER_MAC_STOP_FILE=$PWD/resume-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/resume-test.jsonl aux4 computer mac stop > /dev/null; AUX4_COMPUTER_MAC_STOP_FILE=$PWD/resume-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/resume-test.jsonl aux4 computer mac resume | jq -c '{stopped}'; test -f resume-test.flag || echo removed; AUX4_COMPUTER_MAC_DRY_RUN=1 AUX4_COMPUTER_MAC_STOP_FILE=$PWD/resume-test.flag aux4 computer mac type --text hi --app TextEdit | jq -c '{mode}'
```

```expect
{"stopped":false}
removed
{"mode":"background"}
```

### should succeed when the switch was not on

```execute
AUX4_COMPUTER_MAC_STOP_FILE=$PWD/resume-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/resume-test.jsonl aux4 computer mac resume | jq -c '{stopped}'
```

```expect
{"stopped":false}
```

## with the environment switch

### should say the environment still stops input

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_STOP_FILE=$PWD/resume-test.flag AUX4_COMPUTER_MAC_LOG_FILE=$PWD/resume-test.jsonl aux4 computer mac resume | jq -c '{stopped, stopReason}'
```

```expect
{"stopped":true,"stopReason":"AUX4_COMPUTER_MAC_STOP=1 is set; unset it to allow input"}
```
