# Release Notes

## Fixes

- `shortcut` now presses modifier keys as real key events, so system-wide hotkeys like
  `cmd+space` (Spotlight) work. Before, the modifiers were only attached to the key and
  macOS ignored the combo.
- Tests no longer depend on whether this Mac has granted Accessibility or Screen
  Recording: the missing-permission tests set `AUX4_COMPUTER_MAC_DENY_PERMISSIONS=1`,
  and never send real input to the screen.
