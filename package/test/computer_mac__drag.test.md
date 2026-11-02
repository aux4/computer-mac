# aux4 computer mac drag

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac drag --x 100 --y 100 --toX 200 --toY 200
```

```error:partial
Accessibility permission not granted*?
```
