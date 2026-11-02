#### Description

Types text at the current keyboard focus, unicode-safe (emoji and non-ASCII included). Requires the
Accessibility permission. Use `--delay` to wait before typing — useful right after opening a panel (e.g.
Spotlight) that needs a moment to receive focus.

#### Usage

```bash
aux4 computer mac type <text> [--delay <ms>]
```

text      Text to type (positional)
--delay   Milliseconds to wait before typing (default: `0`)

#### Example

```bash
aux4 computer mac type "Hello, world!" --delay 300
```

```json
{"typed":13}
```
