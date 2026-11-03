#### Description

Turns off the stop switch by removing the shared `~/Library/Application Support/aux4-computer/STOP` (and the old
`~/Library/Application Support/aux4-computer-mac/STOP`, if present), so input and state commands work again — for
this provider and every other, since the switch is shared with `aux4 computer stop|resume`. Succeeds when the switch
was already off. If `AUX4_COMPUTER_STOP=1` or `AUX4_COMPUTER_MAC_STOP=1` is set in the environment, input stays
stopped for that process and the output says so (`"stopped":true` with a `stopReason`). Honours
`AUX4_COMPUTER_STATE_DIR`. Recorded in the action log.

#### Usage

```bash
aux4 computer mac resume
```

#### Example

```bash
aux4 computer mac resume
```

```json
{"file":"/Users/sally/Library/Application Support/aux4-computer/STOP","files":["/Users/sally/Library/Application Support/aux4-computer/STOP","/Users/sally/Library/Application Support/aux4-computer-mac/STOP"],"stopped":false}
```
