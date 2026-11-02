# aux4 computer mac windows

## listing on-screen windows

### should return an array of windows

```execute
aux4 computer mac windows | jq '(.windows | type) == "array"'
```

```expect
true
```
