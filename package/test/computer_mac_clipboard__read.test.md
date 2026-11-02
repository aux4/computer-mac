# aux4 computer mac clipboard read

Saves and restores the clipboard so running the tests doesn't overwrite what the user copied.

```beforeAll
pbpaste > .clipboard-read.bak
```

```afterAll
pbcopy < .clipboard-read.bak && rm -f .clipboard-read.bak
```

## after writing to the clipboard

### should return the same text with no side effects

```execute
aux4 computer mac clipboard copy --text "round trip value" >/dev/null && aux4 computer mac clipboard read | jq .
```

```expect
{
  "text": "round trip value"
}
```
