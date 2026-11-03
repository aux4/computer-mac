# Release notes

- `screenshot --annotate true`: numbered set-of-marks boxes on the window's (or the frontmost app's) actionable
  elements, with `marks` (`n`, `ref`, `role`, `label`, `frame`, `center`, `windowCenter`, `image` box in PNG pixels);
  `--roles all` also marks text, images and headings; `--limit` caps the count (reported as `truncated`).
- `window list|move|resize|minimize|restore|close|fullscreen|raise`: an app's windows by `--title`/`--index`
  through Accessibility, in the background (except `raise`), returning the window before and after; `close`
  reports a "save changes?" sheet as `dialog`.
- `quit` (with `--force`, `--timeout`): reports a save dialog instead of quitting; never force-quits Finder or
  quits session processes. `hide` / `unhide` without activating anything.
- New commands are recorded in the action log (`window move`, ...) and refused while the stop switch is on.
- AI skill `computer-mac` (`aux4 ai skill computer-mac prompt`): the method for agents using this package.
- `type`, `set --value` and `clipboard paste`: when a background Accessibility text edit lands inside a
  document window, the output now adds `"documentEdited": false` and a `"warning"` — macOS doesn't mark
  that window edited for an Accessibility edit, so closing it discards the text without asking. Save
  explicitly (`shortcut cmd+s --app <app>` / `menu --path "File > Save"`) or use `--mode foreground`.
- The live UI test runs on every branch as well as dev and main (reusable `live.yml`).
