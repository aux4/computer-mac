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
