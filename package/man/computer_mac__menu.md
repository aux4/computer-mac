#### Description

Lists an app's menu bar, or presses one of its menu items by path — **in the background** by default:
the item is pressed through Accessibility, without opening the menu on screen, moving the cursor or
bringing the app forward.

- **Without `--path`** — returns the menu bar as a tree: each item's `title`, `ref`, `checked` (for
  items with a check mark; other marks in `mark`), `shortcut` (as a `shortcut --keys` combo such as
  `cmd+shift+s`), `enabled:false` for disabled items, and `children`. `--depth` limits the levels:
  `1` = menu titles, `2` = their items (default), `3`+ = submenus. An item with more levels below the
  depth says `"submenu":true`. Separators are skipped; at most 600 items are listed (`truncated` says so).
- **With `--path`** — titles separated by `>` (`'Format > Font > Bold'`), matched case-insensitively,
  with a trailing `…` / `...` optional and curly apostrophes matching straight ones. Presses the last
  item (`AXPress`) and returns the resolved `path`, its `ref` and, for a toggle item, its new `checked`
  state. When a title doesn't match, the error lists the items available at that level. A path that ends
  on a submenu lists that submenu's items.

Items that act on the app's window (Close, Select All, Undo, Copy…) stay **disabled while the app is in the
background**. In `auto` mode such an item falls back to real input: the app is brought forward, the item is
pressed, and the previously frontmost app and cursor are restored (`fallbackReason` says why). App-level
items (View modes, New, Quit, Settings…) work in the background. `--mode background` errors instead of
falling back. Pressing an item is recorded in the action log and refused while the stop switch is on;
listing is read-only. Requires Accessibility.

#### Usage

```bash
aux4 computer mac menu [--app <name|bundle id>] [--path 'Menu > Item'] [--depth 2] [--mode auto|background|foreground]
```

--app    App whose menu bar to use, by name or bundle id (default: the frontmost app)
--path   Menu item to press, titles separated by `>`; omit to list the menu bar
--depth  Menu levels to list: `1`, `2` (default) or more
--mode   `auto`, `background` or `foreground` (default: `auto`)

#### Example

```bash
aux4 computer mac menu --app Calculator --path "View > Scientific"
```

```json
{"app":"Calculator","checked":true,"method":"AXPress","mode":"background","path":["View","Scientific"],"pressed":"Scientific","ref":"1.3.0.2"}
```

```bash
aux4 computer mac menu --app Calculator --depth 2
```

```json
{"app":"Calculator","depth":2,"menus":[{"ref":"1.3","title":"View","children":[{"checked":true,"ref":"1.3.0.1","shortcut":"cmd+1","title":"Basic"},{"ref":"1.3.0.2","shortcut":"cmd+2","title":"Scientific"},{"ref":"1.3.0.11","submenu":true,"title":"Decimal Places"}]}]}
```
