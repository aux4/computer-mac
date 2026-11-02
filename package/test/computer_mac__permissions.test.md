# aux4 computer mac permissions

## reporting permission status

### should return accessibility and screenRecording keys with granted + guidance

```execute
aux4 computer mac permissions | jq -r '.accessibility.granted, (.accessibility.guidance | type), .screenRecording.granted, (.screenRecording.guidance | type)'
```

```expect:partial
string
**
string
```
