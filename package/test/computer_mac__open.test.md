# aux4 computer mac open

## missing app argument

### should error clearly

```execute
aux4 computer mac open --app ""
```

```error:partial
--app is required
```

## mode decision (dry run, never touches the screen)

### should open without activating by default

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac open TextEdit
```

```expect:json
{
  "dryRun": true,
  "mode": "background",
  "opened": "TextEdit"
}
```

### should bring the app forward with --mode foreground

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac open TextEdit --mode foreground
```

```expect:json
{
  "dryRun": true,
  "mode": "foreground",
  "opened": "TextEdit"
}
```

## files and URLs

```file:notes.txt
meeting notes
```

### should require an app, a file or a URL

```execute
aux4 computer mac open
```

```error
{"error":"--app is required (or give --file or --url)"}
```

### should error when the file does not exist

```execute
aux4 computer mac open --file /no/such/file-0451.txt --app TextEdit
```

```error
{"error":"File not found: /no/such/file-0451.txt"}
```

### should reject a URL without a scheme

```execute
aux4 computer mac open --url aux4.io
```

```error
{"error":"Invalid --url 'aux4.io': include the scheme, e.g. https://aux4.io"}
```

### should not take both a file and a URL

```execute
aux4 computer mac open --file notes.txt --url https://aux4.io
```

```error
{"error":"Give either --file or --url, not both"}
```

### should reject an invalid wait

```execute
aux4 computer mac open TextEdit --wait soon
```

```error
{"error":"Invalid --wait 'soon': use e.g. 500ms, 10s or 2m"}
```

### should reject --hidden with --mode foreground

```execute
aux4 computer mac open TextEdit --hidden true --mode foreground
```

```error
{"error":"--hidden true opens the app without showing it; it can't be combined with --mode foreground"}
```

### should error on an app that isn't installed

```execute
aux4 computer mac open --file notes.txt --app NoSuchApp0451
```

```error
{"error":"App not found: NoSuchApp0451"}
```

### should open a file in an app given by bundle id, in the background (dry run)

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac open --file notes.txt --app com.apple.TextEdit --hidden true | jq -c '{opened, file: (.file | endswith("/notes.txt")), hidden, mode, dryRun}'
```

```expect
{"opened":"com.apple.TextEdit","file":true,"hidden":true,"mode":"background","dryRun":true}
```

### should open a URL with its default app (dry run)

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac open --url https://aux4.io | jq -c '{opened, url, mode}'
```

```expect
{"opened":"https://aux4.io","url":"https://aux4.io","mode":"background"}
```

### should refuse while the stop switch is on

```execute
AUX4_COMPUTER_MAC_STOP=1 AUX4_COMPUTER_MAC_LOG_FILE=$PWD/open-stop.jsonl aux4 computer mac open TextEdit 2>&1 | jq -c '{stopped, command}'; rm -f open-stop.jsonl
```

```expect
{"stopped":true,"command":"open"}
```
