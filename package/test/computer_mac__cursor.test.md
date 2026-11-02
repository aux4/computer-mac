# aux4 computer mac cursor

## reading cursor position

### should return numeric x and y

```execute
aux4 computer mac cursor | jq '(.x | type) == "number" and (.y | type) == "number"'
```

```expect
true
```
