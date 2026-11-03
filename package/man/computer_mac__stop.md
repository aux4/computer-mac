#### Description

Turns on the **stop switch**: creates the `STOP` file in the state directory shared with `aux4/computer` and every
other computer provider, `~/Library/Application Support/aux4-computer/STOP` (and, for one release, the old
`~/Library/Application Support/aux4-computer-mac/STOP`). While it exists, every command that sends input or changes
state (`click`, `type`, `shortcut`, `scroll`, `drag`, `move`, `set`, `select`, `menu --path`, `dialog --press`,
`clipboard copy` / `paste`, `open`, `focus`, `window` except `list`, `quit`, `hide`, `unhide`) refuses with exit code
`1` and a JSON error (`"stopped":true`), before touching anything — dry runs included. Read-only commands (`state`,
`read`, `find`, `screenshot`, `ocr`, `wait`, `menu` without `--path`, `dialog` without `--press`, `log`…) keep working,
so an agent can still look but not act.

The switch is shared: `aux4 computer stop` and `aux4 computer mac stop` are the same switch, and a direct
`aux4 computer mac ...` call can't bypass it. `aux4 computer resume` or `aux4 computer mac resume` turns it off.
Setting `AUX4_COMPUTER_STOP=1` (or the older `AUX4_COMPUTER_MAC_STOP=1`) in the environment has the same effect for
the processes that see it. `AUX4_COMPUTER_STATE_DIR` moves the state directory (the old path is then ignored).
Refusals are recorded in the action log.

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
{"file":"/Users/sally/Library/Application Support/aux4-computer/STOP","files":["/Users/sally/Library/Application Support/aux4-computer/STOP","/Users/sally/Library/Application Support/aux4-computer-mac/STOP"],"stopped":true}
```

```json
{"command":"click","error":"Stopped: aux4 computer mac is not sending input or changing state (/Users/sally/Library/Application Support/aux4-computer/STOP exists). Run 'aux4 computer resume' (or 'aux4 computer mac resume') to allow it again.","stopped":true}
```
