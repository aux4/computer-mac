# aux4 computer mac find

## without accessibility permission

### should error with guidance, never a silent no-op

```execute
AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1 aux4 computer mac find "Save"
```

```error:partial
Accessibility permission not granted*?
```
