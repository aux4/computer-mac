#### Description

Describes this provider for `aux4/computer` as one JSON object. `aux4 computer providers` and every generic
`aux4 computer <command>` read it to check that the installed computer-mac implements the provider contract the core
expects (`contract`), and refuse a provider whose contract differs.

- **provider** — `mac`, the name used in `aux4 computer mac <command>` and `--provider mac`
- **package** — `aux4/computer-mac`
- **contract** — the computer provider contract version implemented (`1`)
- **platform** — `darwin/arm64` or `darwin/amd64`; **os** — the macOS version
- **version** — the installed package version
- **capabilities** — booleans: `background`, `foregroundFallback`, `accessibilityTree`, `ocr`, `annotate`, `menu`,
  `dialog`, `select`, `set`, `state`, `wait`, `window`, `clipboard`, `hide`, `multipleDisplays`
- **permissions** — the same `accessibility` / `screenRecording` objects as `permissions` (`granted`, `guidance`)
- **stateDir**, **stopFile**, **logFile** — where the shared stop switch and action log live (honours
  `AUX4_COMPUTER_STATE_DIR`)

It is read-only and never blocked by the stop switch.

#### Usage

```bash
aux4 computer mac info
```

#### Example

```bash
aux4 computer mac info
```

```json
{"capabilities":{"accessibilityTree":true,"annotate":true,"background":true,"clipboard":true,"dialog":true,"foregroundFallback":true,"hide":true,"menu":true,"multipleDisplays":true,"ocr":true,"select":true,"set":true,"state":true,"wait":true,"window":true},"contract":1,"logFile":"/Users/sally/Library/Application Support/aux4-computer/actions.jsonl","os":"macOS 26.1.0","package":"aux4/computer-mac","permissions":{"accessibility":{"granted":true,"guidance":"Accessibility access is granted."},"screenRecording":{"granted":true,"guidance":"Screen Recording access is granted."}},"platform":"darwin/arm64","provider":"mac","stateDir":"/Users/sally/Library/Application Support/aux4-computer","stopFile":"/Users/sally/Library/Application Support/aux4-computer/STOP","version":"0.7.0"}
```
