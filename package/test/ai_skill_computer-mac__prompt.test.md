# aux4 ai skill computer-mac prompt

Deprecated alias of `aux4 ai skill computer prompt` (aux4/computer), kept for one release.

## printing the skill

### should print the aux4/computer skill

```execute
aux4 ai skill computer-mac prompt | head -1
```

```expect
# Using a computer with aux4/computer
```

### should teach the generic loop followed by the macOS notes

```execute
aux4 ai skill computer-mac prompt
```

```expect:partial
## The loop
**
*aux4 computer state --app <App>*
**
## Platform notes: mac (aux4/computer-mac)
**
### What works in the background
**
```
