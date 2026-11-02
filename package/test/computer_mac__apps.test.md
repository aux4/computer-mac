# aux4 computer mac apps

## listing running applications

### should return an array of apps with name and pid

```execute
aux4 computer mac apps | jq '(.apps | type) == "array" and (.apps | length > 0) and (.apps[0] | has("name") and has("pid") and has("bundleId"))'
```

```expect
true
```
