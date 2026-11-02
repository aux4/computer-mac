import AppKit
import ApplicationServices
import Foundation

// MARK: - menu (list the menu bar / press an item by path)

let keyNameForCode: [Int: String] = {
    var m: [Int: String] = [:]
    for (name, code) in keyCodeMap where m[Int(code)] == nil || name.count > (m[Int(code)] ?? "").count {
        m[Int(code)] = name
    }
    return m
}()

// Key equivalents some apps report as glyphs rather than characters.
let menuGlyphKeys: [String: String] = [
    "\u{238B}": "escape", "\u{1B}": "escape", "\u{232B}": "delete", "\u{8}": "delete", "\u{7F}": "delete",
    "\u{2326}": "forwarddelete", "\u{21A9}": "return", "\r": "return", "\u{3}": "enter", "\u{2324}": "enter",
    "\u{21E5}": "tab", "\t": "tab", "\u{2190}": "left", "\u{2192}": "right", "\u{2191}": "up", "\u{2193}": "down",
    "\u{F702}": "left", "\u{F703}": "right", "\u{F700}": "up", "\u{F701}": "down", "\u{2196}": "home",
    "\u{2198}": "end", "\u{21DE}": "pageup", "\u{21DF}": "pagedown"
]

// menuShortcut renders an item's key equivalent as a 'shortcut --keys' combo (cmd+shift+s).
func menuShortcut(_ item: AXUIElement) -> String? {
    let mods = axNumber(item, kAXMenuItemCmdModifiersAttribute) ?? 0
    var key: String? = nil
    if let ch = axString(item, kAXMenuItemCmdCharAttribute), !ch.isEmpty {
        let lower = ch.lowercased()
        key = menuGlyphKeys[ch] ?? menuCharForKey.first(where: { $0.value == lower })?.key ?? lower
    } else if let vk = axNumber(item, kAXMenuItemCmdVirtualKeyAttribute), vk > 0 {
        // Keys without a character (arrows, F-keys, delete). 0 would be "a", which always has a char.
        key = keyNameForCode[vk]
    }
    guard let k = key else { return nil }
    var parts: [String] = []
    if mods & 16 != 0 { parts.append("fn") }
    if mods & 4 != 0 { parts.append("ctrl") }
    if mods & 2 != 0 { parts.append("alt") }
    if mods & 1 != 0 { parts.append("shift") }
    if mods & 8 == 0 { parts.append("cmd") }
    parts.append(k)
    return parts.joined(separator: "+")
}

func menuTitle(_ item: AXUIElement) -> String {
    return axString(item, kAXTitleAttribute) ?? ""
}

// The items one level below a menu bar item or a menu item (through its AXMenu child).
func menuChildren(_ item: AXUIElement) -> [(AXUIElement, Int, Int)] {
    var out: [(AXUIElement, Int, Int)] = []
    for (mi, menu) in axChildren(item).enumerated() where axString(menu, kAXRoleAttribute) == "AXMenu" {
        for (ii, child) in axChildren(menu).enumerated() {
            out.append((child, mi, ii))
        }
    }
    return out
}

func isSeparator(_ item: AXUIElement) -> Bool {
    return menuTitle(item).isEmpty && axString(item, kAXRoleAttribute) == kAXMenuItemRole
        && menuShortcut(item) == nil && menuChildren(item).isEmpty
}

func menuMark(_ item: AXUIElement) -> String? {
    guard let m = axString(item, kAXMenuItemMarkCharAttribute), !m.isEmpty else { return nil }
    return m
}

func menuBarOf(_ target: Target) -> (AXUIElement, String?) {
    guard let bar = axElementAttr(target.axApp, kAXMenuBarAttribute) else {
        fail("\(target.name) has no menu bar available to Accessibility")
    }
    return (bar, axRefOf(bar, in: target.axApp))
}

func cmdMenu(_ args: [String]) {
    let appArg = argAt(args, 0)
    let pathArg = argAt(args, 1)
    let depthArg = argAt(args, 2)
    let mode = parseMode(argAt(args, 3))
    let depth = depthArg.isEmpty ? 2 : (Int(depthArg) ?? -1)
    guard depth >= 1 else {
        fail("Invalid --depth '\(depthArg)': use 1 (menu titles), 2 (their items) or more for submenus")
    }
    let parts = pathArg.split(separator: ">").map { $0.trimmingCharacters(in: .whitespaces) }
    if !pathArg.isEmpty {
        if parts.contains(where: { $0.isEmpty }) {
            fail("Invalid --path '\(pathArg)': separate menu titles with '>', e.g. 'Format > Font > Bold'")
        }
        if parts.count < 2 {
            fail("Invalid --path '\(pathArg)': give a menu item, not just a menu, e.g. '\(parts.first ?? "File") > ...'")
        }
    }
    requireAccessibility()
    if pathArg.isEmpty {
        listMenu(appArg, depth: depth)
        return
    }
    var base: [String: Any] = ["path": parts]
    if !appArg.isEmpty { base["app"] = appArg }
    if isDryRun() {
        runAction("menu", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    base["app"] = target.name

    func press() -> BackgroundOutcome {
        let (item, titles, ref) = resolveMenuPath(target, parts)
        if !menuChildren(item).isEmpty {
            let options = menuChildren(item).map { menuTitle($0.0) }.filter { !$0.isEmpty }
            fail("'\(titles.joined(separator: " > "))' is a submenu: add one of its items: \(options.joined(separator: ", "))")
        }
        if axBool(item, kAXEnabledAttribute) == false {
            return .unavailable("menu item '\(titles.joined(separator: " > "))' is disabled (while \(target.name) is in the background, items that act on its window stay disabled)")
        }
        let before = menuMark(item)
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        if result != .success {
            return .unavailable("AXPress failed on '\(titles.last ?? "")' (AXError \(result.rawValue))")
        }
        var out: [String: Any] = ["pressed": titles.last ?? "", "path": titles, "method": "AXPress"]
        if let r = ref { out["ref"] = r }
        // A toggle item reports its new state.
        usleep(150_000)
        let after = menuMark(item)
        if before != nil || after != nil {
            out["checked"] = after == "\u{2713}"
        }
        return .done(out)
    }
    runAction("menu", mode: mode, base: base, plan: .attempt(press), targetApp: target.app) {
        switch press() {
        case .done(let out): return out
        case .unavailable(let reason): fail("Could not press the menu item: \(reason)")
        }
    }
}

// resolveMenuPath walks the menu bar by title; the error lists what is available where a title
// didn't match.
func resolveMenuPath(_ target: Target, _ parts: [String]) -> (AXUIElement, [String], String?) {
    let (bar, barRef) = menuBarOf(target)
    var candidates: [(AXUIElement, String?)] = axChildren(bar).enumerated().map { (i, el) in
        (el, barRef.map { $0.isEmpty ? "\(i)" : "\($0).\(i)" })
    }
    var titles: [String] = []
    var current: (AXUIElement, String?)? = nil
    for (level, part) in parts.enumerated() {
        let want = normalizeTitle(part)
        guard let hit = candidates.first(where: { normalizeTitle(menuTitle($0.0)) == want }) else {
            let available = candidates.map { menuTitle($0.0) }.filter { !$0.isEmpty }
            let place = level == 0 ? "in \(target.name)'s menu bar" : "under '\(titles.joined(separator: " > "))'"
            fail("No menu item '\(part)' \(place). Available: \(available.joined(separator: ", "))")
        }
        titles.append(menuTitle(hit.0))
        current = hit
        if level < parts.count - 1 {
            candidates = menuChildren(hit.0).map { (el, mi, ii) in (el, hit.1.map { "\($0).\(mi).\(ii)" }) }
        }
    }
    return (current!.0, titles, current!.1)
}

func listMenu(_ appArg: String, depth: Int) {
    let target = resolveTarget(appArg)
    let (bar, barRef) = menuBarOf(target)
    let cap = 600
    var count = 0
    var truncated = false

    func describe(_ item: AXUIElement, ref: String?, level: Int) -> [String: Any]? {
        if isSeparator(item) { return nil }
        if count >= cap { truncated = true; return nil }
        count += 1
        var e: [String: Any] = ["title": menuTitle(item)]
        if let r = ref { e["ref"] = r }
        if axBool(item, kAXEnabledAttribute) == false { e["enabled"] = false }
        if let mark = menuMark(item) {
            e["checked"] = mark == "\u{2713}"
            if mark != "\u{2713}" { e["mark"] = mark }
        }
        if level > 0, let s = menuShortcut(item) { e["shortcut"] = s }
        let kids = menuChildren(item)
        if !kids.isEmpty {
            if level + 1 < depth {
                e["children"] = kids.compactMap { (el, mi, ii) in
                    describe(el, ref: ref.map { "\($0).\(mi).\(ii)" }, level: level + 1)
                }
            } else {
                e["submenu"] = true
            }
        }
        return e
    }
    let menus = axChildren(bar).enumerated().compactMap { (i, el) in
        describe(el, ref: barRef.map { $0.isEmpty ? "\(i)" : "\($0).\(i)" }, level: 0)
    }
    var out: [String: Any] = ["app": target.name, "menus": menus, "depth": depth]
    if truncated { out["truncated"] = true; out["note"] = "stopped after \(cap) items: use a lower --depth" }
    printJSON(out)
}
