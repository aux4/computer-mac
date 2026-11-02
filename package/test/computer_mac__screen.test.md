# aux4 computer mac screen

## listing displays

### should return at least one display with bounds and scale

```execute
aux4 computer mac screen | jq '.displays | length > 0 and (.[0] | has("id") and has("width") and has("height") and has("scale") and has("main"))'
```

```expect
true
```
