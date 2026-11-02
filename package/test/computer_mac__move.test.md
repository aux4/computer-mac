# aux4 computer mac move

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac move --x 100 --y 100
```

```error:partial
Accessibility permission not granted*?
```
