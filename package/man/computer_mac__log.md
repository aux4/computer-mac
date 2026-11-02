#### Description

Shows the most recent entries of the **action log**. Every command that sends input or changes state —
`click`, `type`, `shortcut`, `scroll`, `drag`, `move`, `set`, `select`, `menu --path`, `dialog --press`,
`clipboard copy` / `paste`, `open`, `focus` — appends one JSON line to
`~/Library/Logs/aux4-computer-mac/actions.jsonl`, whether it succeeded, failed or was refused by the stop
switch. Read-only commands and dry runs are not recorded.

Each entry has `ts` (ISO 8601), `command`, `app`, `args` (the arguments given; `--text` and `--value` are
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
{"entries":[{"app":"TextEdit","args":{"all":"true","app":"TextEdit","mode":"background"},"command":"select","method":"accessibility","mode":"background","ms":62,"result":"ok","ts":"2026-11-02T22:52:10.114Z"},{"app":"Calculator","args":{"app":"Calculator","path":"View > Nope"},"command":"menu","error":"No menu item 'Nope' under 'View'. Available: Basic, Scientific, Programmer","ms":53,"result":"error","ts":"2026-11-02T22:52:12.208Z"}],"path":"/Users/sally/Library/Logs/aux4-computer-mac/actions.jsonl","stopped":false}
```
