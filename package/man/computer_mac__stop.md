#### Description

Turns on the **stop switch**: creates `~/Library/Application Support/aux4-computer-mac/STOP`. While it
exists, every command that sends input or changes state (`click`, `type`, `shortcut`, `scroll`, `drag`,
`move`, `set`, `select`, `menu --path`, `dialog --press`, `clipboard copy` / `paste`, `open`, `focus`)
refuses with exit code `1` and a JSON error (`"stopped":true`), before touching anything — dry runs
included. Read-only commands (`state`, `read`, `find`, `screenshot`, `ocr`, `wait`, `menu` without
`--path`, `dialog` without `--press`, `log`…) keep working, so an agent can still look but not act.

Use it to halt an agent immediately from any terminal; `resume` turns it off. Setting the environment
variable `AUX4_COMPUTER_MAC_STOP=1` has the same effect for the processes that see it. Refusals are
recorded in the action log.

#### Usage

```bash
aux4 computer mac stop
```

#### Example

```bash
aux4 computer mac stop
aux4 computer mac click --app Calculator --x 34 --y 211
```

```json
{"file":"/Users/sally/Library/Application Support/aux4-computer-mac/STOP","stopped":true}
```

```json
{"command":"click","error":"Stopped: aux4 computer mac is not sending input or changing state (/Users/sally/Library/Application Support/aux4-computer-mac/STOP exists). Run 'aux4 computer mac resume' to allow it again.","stopped":true}
```
