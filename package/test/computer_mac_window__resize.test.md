# aux4 computer mac window resize

## validating

### should require --width or --height

```execute
aux4 computer mac window resize --app TextEdit
```

```error
{"error":"--width or --height is required"}
```

### should reject a size that is not positive

```execute
aux4 computer mac window resize --app TextEdit --width 0
```

```error
{"error":"--width and --height must be positive"}
```

## resizing (dry run)

### should resize one side and keep the other

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac window resize --app TextEdit --width 640 | jq -c '{action, mode, requested}'
```

```expect
{"action":"resize","mode":"background","requested":{"width":640}}
```

