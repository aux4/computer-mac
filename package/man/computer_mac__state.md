#### Description

One call that tells an agent where things stand, without changing anything:

- **`frontmost`** — the app in front (`name`, `pid`, `bundleId`)
- **`app`** — the target app (`--app`, by name or bundle id, or the frontmost one): `name`, `pid`,
  `bundleId`, `hidden`, `frontmost`
- **`windows`** — its windows (up to 20): `title`, `ref`, `frame`, and `main` / `focused` / `minimized`
  when true, `subrole` when it isn't a standard window
- **`focused`** — the focused element, in the same shape as a `find` match (`ref`, `role`, `label`,
  `value`, `frame`, `center`, `windowCenter`), or `null`
- **`dialog`** — the open alert / sheet / dialog / save or open panel, as `dialog` reports it, or `null`
- **`elements`** — a compact tree of the open dialog, or else of the focused (or main) window: only
  actionable and text elements (buttons, checkboxes, pop-ups, fields, text, links, sliders…), each with
  `ref`, `role`, `label`, `value` (both cut at 80 characters), `frame` (whole points), `subrole` for
  untitled window buttons (`AXCloseButton`…), `enabled:false` / `focused:true` when so. `root` is the
  ref of the window or dialog the tree starts at. `label` falls back the same way `dialog`/`find`/`read`
  do when an element has no `AXTitle`/`AXDescription`: its `AXTitleUIElement`, then the nearest static
  text to its left on the same row, then the nearest one directly above.

`--depth` counts levels of those elements (layout groups in between don't count; default `3`, `0` = no
tree). `--limit` caps the number of elements (default `120`); when there are more — or the app is so large
that the walk stopped early — `truncated:true` and a `note` say so. Secure text fields never report their
value. Read-only: works while the stop switch is on. Requires Accessibility.

**Note:** refs are child-index paths, valid for the current state of the app — when a window or panel
opens or closes, take a new `state` before acting on a ref.

#### Usage

```bash
aux4 computer mac state [--app <name|bundle id>] [--depth 3] [--limit 120]
```

--app    App to describe (default: the frontmost app)
--depth  Levels of actionable/text elements (default: `3`)
--limit  Maximum number of elements (default: `120`)

#### Example

```bash
aux4 computer mac state --app Calculator
```

```json
{"app":{"bundleId":"com.apple.calculator","frontmost":false,"hidden":false,"name":"Calculator","pid":62830},"depth":3,"dialog":null,"elements":[{"frame":{"height":36,"width":73,"x":609,"y":488},"label":"Edit field","ref":"0.0.0.1.0.1.0","role":"AXStaticText","value":"1,792"},{"frame":{"height":48,"width":48,"x":526,"y":532},"label":"All Clear","ref":"0.0.0.1.0.3","role":"AXButton"}],"focused":{"center":{"x":645.5,"y":506},"enabled":true,"focused":false,"frame":{"height":36,"width":73,"x":609,"y":488},"label":"Edit field","role":"AXUnknown","value":"1,792","windowCenter":{"x":183.5,"y":107}},"frontmost":{"bundleId":"com.anthropic.claudefordesktop","name":"Claude","pid":49456},"root":"0","windows":[{"frame":{"height":408,"width":230,"x":462,"y":399},"main":true,"ref":"0","title":"Calculator"}]}
```
