#### Description

Turns off the stop switch by removing `~/Library/Application Support/aux4-computer-mac/STOP`, so input
and state commands work again. Succeeds when the switch was already off. If `AUX4_COMPUTER_MAC_STOP=1` is
set in the environment, input stays stopped for that process and the output says so (`"stopped":true`
with a `stopReason`). Recorded in the action log.

#### Usage

```bash
aux4 computer mac resume
```

#### Example

```bash
aux4 computer mac resume
```

```json
{"file":"/Users/sally/Library/Application Support/aux4-computer-mac/STOP","stopped":false}
```
