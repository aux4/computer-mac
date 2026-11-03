#### Description

Shows the most recent entries of the **action log**. Every command that sends input or changes state —
`click`, `type`, `shortcut`, `scroll`, `drag`, `move`, `set`, `select`, `menu --path`, `dialog --press`,
`clipboard copy` / `paste`, `open`, `focus`, `window` (except `list`), `quit`, `hide`, `unhide` — appends one JSON
line to `~/Library/Application Support/aux4-computer/actions.jsonl` (mode `0600`), the action log shared with
`aux4/computer` and every other computer provider, whether it succeeded, failed or was refused by the stop switch.
Read-only commands and dry runs are not recorded. `aux4 computer log` shows the same entries. `AUX4_COMPUTER_STATE_DIR`
moves it. Entries written by older releases to `~/Library/Logs/aux4-computer-mac/actions.jsonl` are still shown
(listed in `paths`).

Each entry has `ts` (ISO 8601 UTC with milliseconds), `provider` (`mac`), `command`, `app`, `args` (the arguments given; `--text` and `--value` are
cut to 16 characters plus their length, since typed text can be private), `mode`, `result` (`ok` or
`error`), `error`, `method` / `fallbackReason` when there was one, and `ms` (duration). The file is rotated
at 10MB (the previous one is kept as `actions.jsonl.1` and read too when more entries are asked for).

The output also says whether the stop switch is on (`stopped`, `stopReason`).

#### Usage

```bash
aux4 computer mac log [--limit 20]
```

--limit  Number of recent entries to show, oldest first (default: `20`)

#### Example

```bash
aux4 computer mac log --limit 2
```

```json
{"entries":[{"app":"TextEdit","args":{"all":"true","app":"TextEdit","mode":"background"},"command":"select","method":"accessibility","mode":"background","ms":62,"provider":"mac","result":"ok","ts":"2026-11-02T22:52:10.114Z"},{"app":"Calculator","args":{"app":"Calculator","path":"View > Nope"},"command":"menu","error":"No menu item 'Nope' under 'View'. Available: Basic, Scientific, Programmer","ms":53,"provider":"mac","result":"error","ts":"2026-11-02T22:52:12.208Z"}],"path":"/Users/sally/Library/Application Support/aux4-computer/actions.jsonl","paths":["/Users/sally/Library/Application Support/aux4-computer/actions.jsonl"],"stopped":false}
```
