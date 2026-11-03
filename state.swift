import AppKit
import ApplicationServices
import Foundation

// MARK: - dialog (alerts, sheets, save/open panels)

struct DialogInfo {
    let element: AXUIElement     // the sheet or dialog window
    let kind: String             // sheet | dialog | system-alert | save-panel | open-panel
    let app: Target
}

func axSubrole(_ el: AXUIElement) -> String { axString(el, kAXSubroleAttribute) ?? "" }
func axRole(_ el: AXUIElement) -> String { axString(el, kAXRoleAttribute) ?? "" }

// descendants collects elements under root (breadth-first, bounded) that pass the filter.
func descendants(_ root: AXUIElement, maxDepth: Int = 10, maxNodes: Int = 1500, _ keep: (AXUIElement, String) -> Bool) -> [AXUIElement] {
    var out: [AXUIElement] = []
    var queue: [(AXUIElement, Int)] = [(root, 0)]
    var visited = 0
    while !queue.isEmpty && visited < maxNodes {
        let (el, depth) = queue.removeFirst()
        visited += 1
        if depth > 0 && keep(el, axRole(el)) { out.append(el) }
        if depth < maxDepth {
            for child in axChildren(el) { queue.append((child, depth + 1)) }
        }
    }
    return out
}

func buttonTitle(_ el: AXUIElement) -> String {
    return axString(el, kAXTitleAttribute) ?? axString(el, kAXDescriptionAttribute) ?? ""
}

// dialogKind tells a save/open panel from an alert by its buttons and contents.
func dialogKind(_ container: AXUIElement, base: String) -> String {
    let buttons = descendants(container, maxDepth: 6) { _, role in role == "AXButton" }.map { normalizeTitle(buttonTitle($0)) }
    let hasBrowser = !descendants(container, maxDepth: 8, maxNodes: 600) { _, role in
        ["AXOutline", "AXBrowser", "AXList"].contains(role)
    }.isEmpty
    let hasNameField = !descendants(container, maxDepth: 6) { el, role in
        role == "AXTextField" && ["save as:", "save as"].contains(normalizeTitle(axString(el, kAXDescriptionAttribute) ?? axString(el, kAXTitleAttribute) ?? ""))
    }.isEmpty
    // A "Save As:" label next to the name field (NSSavePanel, also inside "keep this document?" sheets).
    let hasSaveAsLabel = !descendants(container, maxDepth: 6, { el, role in
        role == "AXStaticText" && normalizeTitle(axString(el, kAXValueAttribute) ?? "") == "save as:"
    }).isEmpty
    if hasNameField || hasSaveAsLabel || (buttons.contains("save") && hasBrowser) { return "save-panel" }
    if buttons.contains("open") && hasBrowser { return "open-panel" }
    return base
}

func hasTitledButton(_ container: AXUIElement) -> Bool {
    return !descendants(container, maxDepth: 8, maxNodes: 400, { el, role in role == "AXButton" && !buttonTitle(el).isEmpty }).isEmpty
}

// findDialog returns the app's frontmost sheet or dialog window, if any.
func findDialog(_ target: Target) -> DialogInfo? {
    let windows = axWindows(target.axApp)
    // Sheets first (they block a document window), then dialog windows.
    for win in windows {
        for child in axChildren(win) where axRole(child) == "AXSheet" {
            return DialogInfo(element: child, kind: dialogKind(child, base: "sheet"), app: target)
        }
    }
    for win in windows {
        let sub = axSubrole(win)
        if sub == "AXDialog" || sub == "AXSystemDialog" {
            // Floating helpers (e.g. the Writing Tools button next to a selection) are dialog
            // windows without a titled button: not something to answer.
            if !hasTitledButton(win) { continue }
            return DialogInfo(element: win, kind: dialogKind(win, base: sub == "AXSystemDialog" ? "system-alert" : "dialog"), app: target)
        }
    }
    return nil
}

// System alerts belong to helper processes rather than the app that caused them.
let systemAlertProcesses = ["UserNotificationCenter", "CoreServicesUIAgent"]

func findSystemAlert() -> DialogInfo? {
    for name in systemAlertProcesses {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name || ($0.bundleIdentifier ?? "").hasSuffix(name) }) else { continue }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(axApp, 1.0)
        let target = Target(app: app, name: app.localizedName ?? name, pid: app.processIdentifier, axApp: axApp, explicit: true)
        if let win = axWindows(axApp).first {
            return DialogInfo(element: win, kind: "system-alert", app: target)
        }
    }
    return nil
}

func dialogJSON(_ d: DialogInfo) -> [String: Any] {
    let windowOrigin = frontWindow(pid: d.app.pid)?.frame.origin
    let defaultButton = axElementAttr(d.element, kAXDefaultButtonAttribute)
    let cancelButton = axElementAttr(d.element, kAXCancelButtonAttribute)
    var out: [String: Any] = ["kind": d.kind, "app": d.app.name]
    if let ref = axRefOf(d.element, in: d.app.axApp) { out["ref"] = ref }
    var title = axString(d.element, kAXTitleAttribute) ?? ""
    if title.isEmpty, axRole(d.element) == "AXSheet", let parent = axParent(d.element) {
        out["window"] = axString(parent, kAXTitleAttribute) ?? ""
    }
    if title.isEmpty { title = axString(d.element, kAXDescriptionAttribute) ?? "" }
    out["title"] = title
    if let f = axFrame(d.element) { out["frame"] = frameJSON(f) }

    let texts = descendants(d.element, maxDepth: 6) { _, role in role == "AXStaticText" }
        .compactMap { el -> String? in
            let t = (axString(el, kAXValueAttribute) ?? axString(el, kAXTitleAttribute) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
    var uniqueTexts: [String] = []
    for t in texts where !uniqueTexts.contains(t) && uniqueTexts.count < 10 { uniqueTexts.append(t) }
    out["text"] = uniqueTexts

    var buttons: [[String: Any]] = []
    for el in descendants(d.element, maxDepth: 8, { _, role in role == "AXButton" }) {
        let t = buttonTitle(el)
        if t.isEmpty { continue }
        if buttons.count >= 25 { out["buttonsTruncated"] = true; break }
        var node = describeElement(el, ref: axRefOf(el, in: d.app.axApp) ?? "")
        node = AXNode(ref: node.ref, role: node.role, label: t, value: node.value, frame: node.frame, enabled: node.enabled, focused: node.focused)
        var entry = axMatchEntry(node, windowOrigin: windowOrigin)
        entry["title"] = t
        entry["default"] = defaultButton.map { CFEqual($0, el) } ?? false
        entry["cancel"] = cancelButton.map { CFEqual($0, el) } ?? false
        buttons.append(entry)
    }
    out["buttons"] = buttons

    var fields: [[String: Any]] = []
    let fieldRoles: Set<String> = ["AXTextField", "AXCheckBox", "AXPopUpButton", "AXComboBox", "AXSearchField", "AXSecureTextField", "AXRadioButton"]
    for el in descendants(d.element, maxDepth: 8, { _, role in fieldRoles.contains(role) }) {
        if fields.count >= 15 { out["fieldsTruncated"] = true; break }
        let node = describeElement(el, ref: axRefOf(el, in: d.app.axApp) ?? "")
        var entry = axMatchEntry(node, windowOrigin: windowOrigin)
        // A secure field's value is never reported.
        if node.role == "AXSecureTextField" { entry["value"] = "" }
        fields.append(entry)
    }
    out["fields"] = fields
    return out
}

func cmdDialog(_ args: [String]) {
    let appArg = argAt(args, 0)
    let pressArg = argAt(args, 1)
    let mode = parseMode(argAt(args, 2))
    requireAccessibility()
    if !pressArg.isEmpty && isDryRun() {
        var base: [String: Any] = ["pressed": pressArg]
        if !appArg.isEmpty { base["app"] = appArg }
        runAction("dialog", mode: mode, base: base, plan: .attempt({ .unavailable("dry run") })) { [:] }
        return
    }
    let target = resolveTarget(appArg)
    var dialog = findDialog(target)
    if dialog == nil && appArg.isEmpty { dialog = findSystemAlert() }

    if pressArg.isEmpty {
        printJSON(["app": target.name, "dialog": (dialog.map(dialogJSON) as Any?) ?? NSNull()])
        return
    }
    guard let d = dialog else {
        fail("No dialog, sheet or alert open in \(target.name)")
    }
    var base: [String: Any] = ["app": d.app.name, "kind": d.kind]

    func press() -> BackgroundOutcome {
        // Re-read the dialog: in a fallback the app was just brought forward.
        let current = findDialog(d.app) ?? d
        let buttons = descendants(current.element, maxDepth: 8) { _, role in role == "AXButton" }
        let want = normalizeTitle(pressArg)
        guard let button = buttons.first(where: { normalizeTitle(buttonTitle($0)) == want }) else {
            let titles = buttons.map(buttonTitle).filter { !$0.isEmpty }
            fail("No button '\(pressArg)' in the \(current.kind). Buttons: \(titles.joined(separator: ", "))")
        }
        // The button is gone once the dialog closes: keep its title.
        let title = buttonTitle(button)
        if axBool(button, kAXEnabledAttribute) == false {
            return .unavailable("button '\(title)' is disabled")
        }
        let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
        if result != .success {
            return .unavailable("AXPress failed on '\(title)' (AXError \(result.rawValue))")
        }
        // Report whether the dialog went away (a Save panel may be followed by another alert).
        var closed = false
        for _ in 0..<20 {
            usleep(50_000)
            let still = findDialog(d.app).map { CFEqual($0.element, current.element) } ?? false
            if !still {
                closed = true
                break
            }
        }
        var out: [String: Any] = ["pressed": title, "method": "AXPress", "closed": closed]
        if let next = findDialog(d.app), !CFEqual(next.element, current.element) {
            out["next"] = dialogJSON(next)
        }
        return .done(out)
    }
    base["dialog"] = ["kind": d.kind, "title": axString(d.element, kAXTitleAttribute) ?? ""]
    runAction("dialog", mode: mode, base: base, plan: .attempt(press), targetApp: d.app.app) {
        switch press() {
        case .done(let out): return out
        case .unavailable(let reason): fail("Could not press the button: \(reason)")
        }
    }
}

// MARK: - state (one-call snapshot for an agent)

let compactRoles: Set<String> = [
    "AXButton", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXSlider",
    "AXIncrementor", "AXLink", "AXDisclosureTriangle", "AXTextField", "AXTextArea", "AXComboBox",
    "AXSearchField", "AXSecureTextField", "AXStaticText", "AXTab", "AXSwitch", "AXColorWell", "AXHeading"
]

func cmdState(_ args: [String]) {
    let appArg = argAt(args, 0)
    let depthArg = argAt(args, 1)
    let limitArg = argAt(args, 2)
    let depth = depthArg.isEmpty ? 3 : (Int(depthArg) ?? -1)
    let limit = limitArg.isEmpty ? 120 : (Int(limitArg) ?? -1)
    guard depth >= 0 else { fail("Invalid --depth '\(depthArg)': use 0 or more") }
    guard limit > 0 else { fail("Invalid --limit '\(limitArg)': use a positive number") }
    requireAccessibility()

    var out: [String: Any] = [:]
    if let pid = frontmostAppPid(), let front = NSRunningApplication(processIdentifier: pid) {
        out["frontmost"] = ["name": front.localizedName ?? "", "pid": Int(pid), "bundleId": front.bundleIdentifier ?? ""]
    }
    let target = resolveTarget(appArg)
    let app = target.app
    out["app"] = [
        "name": target.name,
        "pid": Int(target.pid),
        "bundleId": app.bundleIdentifier ?? "",
        "hidden": app.isHidden,
        "frontmost": isFrontmost(target.pid)
    ]

    let appChildren = axChildren(target.axApp)
    func refOfChild(_ el: AXUIElement) -> String? {
        return appChildren.firstIndex(where: { CFEqual($0, el) }).map(String.init)
    }
    let axWins = axWindows(target.axApp)
    var windows: [[String: Any]] = []
    for w in axWins.prefix(20) {
        var e: [String: Any] = ["title": axString(w, kAXTitleAttribute) ?? ""]
        if let r = refOfChild(w) { e["ref"] = r }
        if let f = axFrame(w) { e["frame"] = frameJSON(f) }
        if axBool(w, kAXMainAttribute) == true { e["main"] = true }
        if axBool(w, kAXFocusedAttribute) == true { e["focused"] = true }
        if axBool(w, kAXMinimizedAttribute) == true { e["minimized"] = true }
        let sub = axSubrole(w)
        if !sub.isEmpty && sub != "AXStandardWindow" { e["subrole"] = sub }
        windows.append(e)
    }
    out["windows"] = windows
    let windowOrigin = frontWindow(pid: target.pid)?.frame.origin

    if let focused = focusedElement(target) {
        let ref = axRefOf(focused, in: target.axApp)
        var f = axMatchEntry(describeElement(focused, ref: ref ?? ""), windowOrigin: windowOrigin)
        // Some focused elements aren't reachable from the app's tree (no ref to act on).
        if ref == nil { f.removeValue(forKey: "ref") }
        if let v = f["value"] as? String, v.count > 200 { f["value"] = String(v.prefix(200)) + "…" }
        if f["role"] as? String == "AXSecureTextField" { f["value"] = "" }
        out["focused"] = f
    } else {
        out["focused"] = NSNull()
    }
    let dialog = findDialog(target)
    out["dialog"] = (dialog.map(dialogJSON) as Any?) ?? NSNull()

    // The compact tree: actionable and text elements of the dialog (if one is open) or the focused/
    // main window. Containers that are neither are skipped, their contents kept, so --depth counts
    // levels of meaningful elements rather than layout groups.
    let root: AXUIElement? = dialog?.element
        ?? axElementAttr(target.axApp, kAXFocusedWindowAttribute)
        ?? axElementAttr(target.axApp, kAXMainWindowAttribute)
        ?? axWins.first
    var elements: [[String: Any]] = []
    var total = 0
    var visited = 0
    let started = Date()
    var cutShort = false
    if let root = root, let rootRef = axRefOf(root, in: target.axApp) {
        out["root"] = rootRef
        func visit(_ el: AXUIElement, ref: String, level: Int, rawDepth: Int) {
            if rawDepth > 30 { return }
            if visited >= 4000 || Date().timeIntervalSince(started) > 4 { cutShort = true; return }
            visited += 1
            let role = axRole(el)
            var keep = compactRoles.contains(role)
            var label = ""
            var value = ""
            if keep {
                label = axString(el, kAXTitleAttribute) ?? axString(el, kAXDescriptionAttribute) ?? ""
                value = axString(el, kAXValueAttribute) ?? ""
                if role == "AXStaticText" && label.isEmpty && value.isEmpty { keep = false }
            }
            var nextLevel = level
            if keep {
                total += 1
                nextLevel = level + 1
                if elements.count < limit {
                    var e: [String: Any] = ["ref": ref, "role": role]
                    if !label.isEmpty { e["label"] = label.count > 80 ? String(label.prefix(80)) + "…" : label }
                    // Untitled window buttons say what they are by subrole (AXCloseButton...).
                    if label.isEmpty, role == "AXButton" { let sub = axSubrole(el); if !sub.isEmpty { e["subrole"] = sub } }
                    if role == "AXSecureTextField" { value = "" }
                    if !value.isEmpty { e["value"] = value.count > 80 ? String(value.prefix(80)) + "…" : value }
                    if let f = axFrame(el) {
                        e["frame"] = ["x": Int(f.origin.x), "y": Int(f.origin.y), "width": Int(f.width), "height": Int(f.height)]
                    }
                    if axBool(el, kAXEnabledAttribute) == false { e["enabled"] = false }
                    if axBool(el, kAXFocusedAttribute) == true { e["focused"] = true }
                    elements.append(e)
                }
                if nextLevel >= depth { return }
            }
            // Text areas hold runs/lines, not controls.
            if role == "AXTextArea" || role == "AXStaticText" { return }
            for (i, child) in axChildren(el).enumerated() {
                visit(child, ref: ref.isEmpty ? "\(i)" : "\(ref).\(i)", level: nextLevel, rawDepth: rawDepth + 1)
            }
        }
        if depth > 0 {
            for (i, child) in axChildren(root).enumerated() {
                visit(child, ref: rootRef.isEmpty ? "\(i)" : "\(rootRef).\(i)", level: 0, rawDepth: 1)
            }
        }
    }
    out["elements"] = elements
    out["depth"] = depth
    if total > elements.count || cutShort {
        out["truncated"] = true
        out["note"] = cutShort
            ? "stopped walking after \(visited) elements: showing \(elements.count); use 'find' or 'read' for more"
            : "showing \(elements.count) of \(total) elements: raise --limit or use 'find'/'read'"
    }
    printJSON(out)
}
