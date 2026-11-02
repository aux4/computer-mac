# aux4 computer mac focus

## missing app argument

### should error clearly

```execute
aux4 computer mac focus --app ""
```

```error:partial
--app is required
```

## app not running

### should error clearly

```execute
aux4 computer mac focus --app "ThisAppDoesNotExist12345"
```

```error:partial
App not running*?
```

## mode

### should always report foreground

```execute
AUX4_COMPUTER_MAC_DRY_RUN=1 aux4 computer mac focus Finder
```

```expect:json
{
  "dryRun": true,
  "focused": "Finder",
  "mode": "foreground",
  "success": true
}
```
