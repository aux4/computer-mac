# aux4 computer mac clipboard paste

## without accessibility permission

### should error with guidance, never a silent no-op, even with --text given

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac clipboard paste --text "won't be pasted"
```

```error:partial
Accessibility permission not granted*?
```
