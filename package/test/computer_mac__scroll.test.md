# aux4 computer mac scroll

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac scroll --dy -100
```

```error:partial
Accessibility permission not granted*?
```
