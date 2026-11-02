# aux4 computer mac clipboard read

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
