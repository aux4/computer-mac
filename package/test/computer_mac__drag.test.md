# aux4 computer mac drag

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac drag --x 100 --y 100 --toX 200 --toY 200
```

```error:partial
Accessibility permission not granted*?
```

## mode

### should always report foreground

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac drag --x 10 --y 20 --toX 30 --toY 40
```

```expect:json
{
  "from": {
    "x": 10,
    "y": 20
  },
  "mode": "foreground",
  "to": {
    "x": 30,
    "y": 40
  }
}
```
