# aux4 computer mac notes

## printing the macOS notes

### should cover permissions, background limits, data loss, OCR, coordinates and labels

```execute
aux4 computer mac notes | grep '^### '
```

```expect
### Permissions (TCC)
### What works in the background
### Silent data loss (documentEdited)
### OCR
### Coordinates and Retina
### App names and labels
### Stop switch and log on macOS
```

### should warn that editing menu items are disabled in the background

```execute
aux4 computer mac notes
```

```expect:partial
**
*Editing menu items are disabled in the background*
**
*sudo killall ANECompilerService*
**
```

### should be appended to the aux4/computer skill

```execute
aux4 ai skill computer prompt --provider mac
```

```expect:partial
# Using a computer with aux4/computer
**
## Platform notes: mac (aux4/computer-mac)
**
### Silent data loss (documentEdited)
**
```
