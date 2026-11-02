# aux4 ai skill computer-mac prompt

## printing the skill

### should start with its title and summary

```execute
aux4 ai skill computer-mac prompt | head -3
```

```expect
# Using a Mac with aux4/computer-mac

Drive macOS apps in the background with `aux4 computer mac`: look (state, find, ocr, screenshot --annotate), act by ref, wait.
```

### should teach the loop with the commands to run

```execute
aux4 ai skill computer-mac prompt
```

```expect:partial
## The loop
**
*aux4 computer mac state --app <App>*
**
*aux4 computer mac screenshot --app <App> --annotate true*
**
*aux4 computer mac wait --app <App> --text "Saved" --timeout 10s*
```

### should cover background limits, coordinates, safety, permissions and troubleshooting

```execute
aux4 ai skill computer-mac prompt | grep '^## '
```

```expect
## The loop
## Background and its limits
## Coordinates
## Safety
## Permissions
## Troubleshooting
```
