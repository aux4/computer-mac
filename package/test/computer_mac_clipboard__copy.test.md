# aux4 computer mac clipboard copy

## with --text

### should write directly to the clipboard without needing accessibility

```execute
aux4 computer mac clipboard copy --text "hello from test" | jq .
```

```expect
{
  "text": "hello from test"
}
```

## without --text and without accessibility permission

### should error with guidance, never a silent no-op

```execute
aux4 computer mac clipboard copy
```

```error:partial
Accessibility permission not granted*?
```
