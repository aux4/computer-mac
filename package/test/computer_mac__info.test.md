# aux4 computer mac info

## describing the provider

### should report the provider name and contract version

```execute
aux4 computer mac info | jq -c '{provider, contract, package}'
```

```expect
{"provider":"mac","contract":1,"package":"aux4/computer-mac"}
```

### should report the platform as darwin/<arch> and the package version

```execute
aux4 computer mac info | jq -c '{platform: (.platform | test("^darwin/(arm64|amd64)$")), version: (.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+"))}'
```

```expect
{"platform":true,"version":true}
```

### should report capabilities as booleans

```execute
aux4 computer mac info | jq -c '{types: ([.capabilities[] | type] | unique), background: .capabilities.background, ocr: .capabilities.ocr, annotate: .capabilities.annotate}'
```

```expect
{"types":["boolean"],"background":true,"ocr":true,"annotate":true}
```

### should report Accessibility and Screen Recording like the permissions command

```execute
AUX4_COMPUTER_DENY_PERMISSIONS=1 aux4 computer mac info | jq -c '.permissions | {accessibility: .accessibility.granted, screenRecording: .screenRecording.granted}'
```

```expect
{"accessibility":false,"screenRecording":false}
```

### should report the shared state directory it uses

```execute
AUX4_COMPUTER_STATE_DIR=/tmp/aux4-computer-info-test aux4 computer mac info | jq -c '{stateDir, stopFile, logFile}'
```

```expect
{"stateDir":"/tmp/aux4-computer-info-test","stopFile":"/tmp/aux4-computer-info-test/STOP","logFile":"/tmp/aux4-computer-info-test/actions.jsonl"}
```

## accepted by aux4/computer

### should be listed by 'aux4 computer providers' as a contract 1 provider

```execute
aux4 computer providers --provider mac | jq -c '.providers[] | select(.provider == "mac") | {status, contract}'
```

```expect
{"status":"ok","contract":1}
```
