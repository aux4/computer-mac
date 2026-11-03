# Release notes

- computer-mac is now the macOS provider of `aux4/computer` (provider contract 1) and depends on it: on a Mac,
  `aux4 computer <command>` runs the same command here. Every `aux4 computer mac ...` command keeps working unchanged.
- `aux4 computer mac info`: provider `mac`, contract `1`, platform, version, capabilities and permissions as JSON
  (what `aux4 computer providers` reads).
- `aux4 computer mac notes`: the macOS specifics for agents (TCC permissions, background limits such as editing menu
  items being disabled in the background, the `documentEdited` data-loss warning, the slow first OCR run and its fix,
  Retina coordinates, Calculator label differences between macOS versions).
- AI skill: `aux4 ai skill computer prompt` (from `aux4/computer`) is the skill now, with the macOS notes appended.
  `aux4 ai skill computer-mac prompt` prints the same thing as a deprecated alias, kept for one release.
- Stop switch and action log are shared with `aux4/computer` and its other providers:
  `~/Library/Application Support/aux4-computer/STOP` and `.../aux4-computer/actions.jsonl` (mode 0600). So
  `aux4 computer stop` also stops direct `aux4 computer mac ...` calls. For one release the old
  `~/Library/Application Support/aux4-computer-mac/STOP` and `AUX4_COMPUTER_MAC_STOP=1` still stop input, and `log`
  still shows entries in the old `~/Library/Logs/aux4-computer-mac/actions.jsonl`.
- Log entries include `"provider":"mac"`; `stop` / `resume` entries now carry millisecond timestamps like the others.
- `AUX4_COMPUTER_STATE_DIR` relocates the shared state; `AUX4_COMPUTER_STOP`, `AUX4_COMPUTER_DRY_RUN`,
  `AUX4_COMPUTER_SIMULATE_BACKGROUND` and `AUX4_COMPUTER_DENY_PERMISSIONS` are accepted, with the
  `AUX4_COMPUTER_MAC_*` names kept as aliases.
- CI runs the `aux4/computer` conformance suite (`aux4 computer conformance --provider mac`).
